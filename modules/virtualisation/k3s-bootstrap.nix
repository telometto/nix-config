{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sys.services.k3s.bootstrap;

  bootstrapScript = pkgs.writeShellScript "k3s-helm-bootstrap" ''
    set -euo pipefail

    # Full paths set by serviceConfig.Environment; add them here for safety
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    export HELM_BIN=${pkgs.kubernetes-helm}/bin/helm

    run_helmfile_phase() {
      phase="$1"
      ${pkgs.helmfile}/bin/helmfile \
        --quiet \
        --file /etc/k3s/helmfile.yaml \
        --selector "phase=$phase" \
        sync
    }

    wait_for_cilium_connectivity() {
      echo "k3s-helm-bootstrap: waiting for Cilium daemonset..."
      ${pkgs.kubectl}/bin/kubectl -n kube-system rollout status daemonset/cilium --timeout=5m

      echo "k3s-helm-bootstrap: verifying pod -> Kubernetes API ClusterIP connectivity..."
      ${pkgs.kubectl}/bin/kubectl delete pod k3s-cilium-smoke --ignore-not-found --wait=true --timeout=60s >/dev/null 2>&1 || true
      ${pkgs.kubectl}/bin/kubectl run k3s-cilium-smoke \
        --image=curlimages/curl:8.8.0 \
        --restart=Never \
        --command -- sh -ec '
          code="$(curl -k -sS -o /tmp/healthz-body -w "%{http_code}" https://10.43.0.1:443/healthz || true)"
          echo "kubernetes API healthz HTTP status: $code"
          test "$code" = "401" || test "$code" = "403"
        '

      if ! ${pkgs.kubectl}/bin/kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/k3s-cilium-smoke --timeout=180s; then
        ${pkgs.kubectl}/bin/kubectl describe pod k3s-cilium-smoke || true
        ${pkgs.kubectl}/bin/kubectl logs k3s-cilium-smoke || true
        ${pkgs.kubectl}/bin/kubectl delete pod k3s-cilium-smoke --ignore-not-found --wait=true --timeout=60s >/dev/null 2>&1 || true
        exit 1
      fi

      ${pkgs.kubectl}/bin/kubectl logs k3s-cilium-smoke || true
      ${pkgs.kubectl}/bin/kubectl delete pod k3s-cilium-smoke --ignore-not-found --wait=true --timeout=60s >/dev/null 2>&1 || true
    }

    check_done() {
      ${pkgs.kubectl}/bin/kubectl get crds --no-headers 2>/dev/null \
        | ${pkgs.gnugrep}/bin/grep -Eo 'cilium\.io|toolkit\.fluxcd\.io' \
        | sort -u | wc -l | grep -q 2
    }

    if check_done; then
      echo "k3s-helm-bootstrap: already complete (CRDs present)"
      exit 0
    fi

    echo "k3s-helm-bootstrap: installing Cilium..."
    run_helmfile_phase cni
    wait_for_cilium_connectivity

    echo "k3s-helm-bootstrap: installing Flux..."
    run_helmfile_phase flux
    echo "k3s-helm-bootstrap: done"
  '';

  helmfileText = ''
    repositories:
      - name: cilium
        url: https://helm.cilium.io

    releases:
      - name: cilium
        namespace: kube-system
        labels:
          phase: cni
        chart: cilium/cilium
        version: "${cfg.ciliumChartVersion}"
        values: ["${cfg.ciliumValuesFile}"]
        createNamespace: true
        wait: true

      - name: flux-operator
        namespace: flux-system
        labels:
          phase: flux
        chart: oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator
        version: "${cfg.fluxOperatorVersion}"
        createNamespace: true
        wait: true

      - name: flux-instance
        namespace: flux-system
        labels:
          phase: flux
        chart: oci://ghcr.io/controlplaneio-fluxcd/charts/flux-instance
        version: "${cfg.fluxInstanceVersion}"
        values: ["${cfg.fluxValuesFile}"]
        wait: true
        needs:
          - flux-system/flux-operator
  '';
in
{
  options.sys.services.k3s.bootstrap = {
    enable = lib.mkEnableOption "helmfile-driven k3s bootstrap (Cilium + Flux)";

    ciliumChartVersion = lib.mkOption {
      type = lib.types.str;
      default = "1.19.3";
      description = "Cilium Helm chart version. Pinned exact — 1.16.x had zero pod connectivity on kernel 6.18.26.";
    };

    ciliumValuesFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Vendored Cilium Helm values YAML. Used by helmfile at OS bootstrap time, before
        Flux is installed — Flux variable substitution (''${VAR}) is not available here.
        Keep in sync with homelab-apps/network/cilium-helmrelease.yaml.
      '';
    };

    fluxOperatorVersion = lib.mkOption {
      type = lib.types.str;
      default = "0.33.0";
      description = "controlplaneio-fluxcd flux-operator chart version.";
    };

    fluxInstanceVersion = lib.mkOption {
      type = lib.types.str;
      default = "0.33.0";
      description = "controlplaneio-fluxcd flux-instance chart version.";
    };

    fluxValuesFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Flux-instance Helm values YAML. Configures the GitRepository URL, branch, path,
        and SSH pull secret so flux-instance knows where to sync from.
      '';
    };

    fluxGitAuthSecretFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to the flux-system SSH auth Secret YAML (sops-nix decrypted path).
        When set, the secret is pre-staged into the k3s auto-apply manifests dir so
        flux-instance can authenticate to the Git remote on first boot.

        Generate from your flux SSH key:
          nix run nixpkgs#fluxcd -- create secret git flux-system \
            --url="ssh://git@github.com/telometto/homelab-apps" \
            --private-key-file=~/.ssh/id_ed25519 \
            --export > flux-git-auth-secret.yaml

        Then store it in nix-secrets, encrypt with sops, and set:
          fluxGitAuthSecretFile = config.sops.secrets."flux-git-auth".path;
      '';
    };

    delaySeconds = lib.mkOption {
      type = lib.types.int;
      default = 180;
      description = "Seconds after boot before the first helmfile sync attempt.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = (config.sys.services.k3s.enable or false) || (config.services.k3s.enable or false);
        message = "sys.services.k3s.bootstrap.enable requires sys.services.k3s.enable or services.k3s.enable.";
      }
    ];

    environment.systemPackages = with pkgs; [
      helmfile
      kubernetes-helm
      fluxcd
    ];

    environment.etc."k3s/helmfile.yaml".text = helmfileText;

    systemd = {
      tmpfiles.rules = [
        # Always remove a previously-staged manifest so that unsetting
        # fluxGitAuthSecretFile does not leave stale Git credentials in k3s's
        # auto-apply directory.
        "R /var/lib/rancher/k3s/server/manifests/flux-git-auth.yaml - - - -"
      ]
      ++ lib.optionals (cfg.fluxGitAuthSecretFile != null) [
        # L+ replaces the symlink if it already points elsewhere (e.g. the sops
        # decrypted path changed between rebuilds).
        "L+ /var/lib/rancher/k3s/server/manifests/flux-git-auth.yaml - - - - ${cfg.fluxGitAuthSecretFile}"
      ];

      services.k3s-helm-bootstrap = {
        description = "Bootstrap k3s: install Cilium and Flux via helmfile";
        after = [ "k3s.service" ];
        requires = [ "k3s.service" ];
        path = with pkgs; [
          coreutils
          gnugrep
          kubectl
          kubernetes-helm
          helmfile
        ];
        environment.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = bootstrapScript;
        };
      };

      timers.k3s-helm-bootstrap = {
        description = "Retry k3s helmfile bootstrap until Cilium and Flux CRDs exist";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "${toString cfg.delaySeconds}s";
          OnUnitInactiveSec = "3min";
          Unit = "k3s-helm-bootstrap.service";
        };
      };
    };
  };
}
