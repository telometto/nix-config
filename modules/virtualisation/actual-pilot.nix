{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.sys.virtualisation.actualPilot;
  stateDir = "/var/lib/rancher/k3s-actual-pilot";
  kubeconfig = "/etc/rancher/k3s-actual-pilot/k3s.yaml";
  fluxComponents = pkgs.fetchurl {
    url = "https://github.com/fluxcd/flux2/releases/download/v2.10.1/install.yaml";
    hash = "sha256-TbL7nOF5YiMn06mjanZbv8Ayn9UGkOjTfafdCRiwk5I=";
  };
  python = pkgs.python3.withPackages (p: [ p.pyyaml ]);
  providerBins = pkgs.runCommand "actual-pilot-empty-credential-providers" { } "mkdir $out";
  providerConfig = "/etc/k3s-actual-pilot/no-credential-providers.yaml";
  enabledPreviews = lib.filterAttrs (_: preview: preview.enable) cfg.previewVMs;
  previewDiskDirs = lib.concatLists (
    lib.mapAttrsToList (
      name: preview: map (disk: "/flash/enc/vms/kubevirt-pilot/${name}/${disk}") preview.disks
    ) enabledPreviews
  );
  safeName =
    name:
    builtins.match "[a-z0-9]([a-z0-9-]*[a-z0-9])?" name != null && builtins.stringLength name <= 63;
  preflightConfig = {
    inherit stateDir;
    diskDirs = [
      "/flash/enc/vms/kubevirt-pilot/actual/root"
      "/flash/enc/vms/kubevirt-pilot/actual/data"
    ]
    ++ previewDiskDirs;
    defaultKubeconfig = "/etc/rancher/k3s/k3s.yaml";
    pilotKubeconfig = kubeconfig;
    firstStartFiles = [
      "/etc/rancher/node/password"
      "/run/k3s/containerd/containerd.sock"
      "/run/flannel/subnet.env"
    ];
    firstStartDirectories = [
      "/var/lib/kubelet/device-plugins"
      "/var/lib/cni/networks/cbr0"
    ];
    absentAlways = [ providerConfig ];
  }
  // lib.optionalAttrs (previewDiskDirs != [ ]) { inherit previewDiskDirs; };
  preflightPaths = pkgs.writeText "actual-pilot-preflight.json" (builtins.toJSON preflightConfig);
  firewallText = ''
    table inet actual_pilot_control
    delete table inet actual_pilot_control
    table inet actual_pilot_control {
      chain prerouting {
        type filter hook prerouting priority -90; policy accept;
        iifname "lo" return
        fib daddr type local iifname != "cni0" tcp dport { 6443, 10250 } counter drop
        fib daddr type local udp dport 8472 counter drop
      }
    }
  '';
  firewallRules = pkgs.writeText "actual-pilot-control.nft" firewallText;
  sync = pkgs.writeText "actual-pilot-flux-sync.json" (
    builtins.toJSON {
      apiVersion = "v1";
      kind = "List";
      items = [
        {
          apiVersion = "source.toolkit.fluxcd.io/v1";
          kind = "GitRepository";
          metadata = {
            name = "actual-pilot";
            namespace = "flux-system";
          };
          spec = {
            interval = "1m";
            url = "https://github.com/telometto/homelab-apps.git";
            ref.branch = cfg.gitBranch;
          };
        }
        {
          apiVersion = "kustomize.toolkit.fluxcd.io/v1";
          kind = "Kustomization";
          metadata = {
            name = "actual-pilot";
            namespace = "flux-system";
          };
          spec = {
            interval = "2m";
            path = "./clusters/blizzard-actual-pilot";
            prune = false;
            sourceRef = {
              kind = "GitRepository";
              name = "actual-pilot";
            };
            timeout = "5m";
            wait = false;
          };
        }
      ];
    }
  );
  virtctl = pkgs.stdenvNoCC.mkDerivation {
    pname = "actual-pilot-virtctl";
    version = "1.9.1";
    src = pkgs.fetchurl {
      url = "https://github.com/kubevirt/kubevirt/releases/download/v1.9.1/virtctl-v1.9.1-linux-amd64";
      hash = "sha256-wok5PIGGolhlNZRgX1GZtMFxoxMebkCe0gSpa0kbeCo=";
    };
    dontUnpack = true;
    dontBuild = true;
    installPhase = ''
      install -Dm755 "$src" "$out/bin/virtctl"
    '';
    meta.platforms = [ "x86_64-linux" ];
  };
in
{
  options.sys.virtualisation.actualPilot = {
    enable = lib.mkEnableOption "private Actual KubeVirt pilot";
    nodeIP = lib.mkOption {
      type = lib.types.str;
      description = "Blizzard LAN address advertised to pilot pods; the API stays firewalled.";
    };
    gitBranch = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "Initial public homelab-apps source branch. Existing Flux objects are managed in Git.";
    };
    previewVMs = lib.mkOption {
      default = { };
      description = "Opt-in retained disks for independent private VM previews. Does not start a VM or resume Flux.";
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            enable = lib.mkEnableOption "host disk preparation for this private VM preview";
            disks = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ "root" ];
              description = "Unique disk names below this preview's dedicated pilot directory.";
            };
          };
        }
      );
    };
    preflightConfig = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      internal = true;
      description = "Metadata-only retained disk/runtime guard inputs.";
    };
    firewallRules = lib.mkOption {
      type = lib.types.lines;
      readOnly = true;
      internal = true;
      description = "Rendered pilot-only early control-plane ingress policy.";
    };
  };

  config = lib.mkIf cfg.enable {
    sys.virtualisation.actualPilot = {
      firewallRules = firewallText;
      inherit preflightConfig;
    };
    assertions = [
      {
        assertion = lib.all (
          name:
          safeName name
          && !(lib.elem name [
            "actual"
            "actual-pilot"
            "restore-tests"
          ])
        ) (builtins.attrNames cfg.previewVMs);
        message = "Preview names must be DNS labels distinct from Actual and restore-tests.";
      }
      {
        assertion = lib.all (
          preview:
          preview.disks != [ ]
          && lib.all safeName preview.disks
          && builtins.length (lib.unique preview.disks) == builtins.length preview.disks
        ) (builtins.attrValues cfg.previewVMs);
        message = "Preview disk names must be nonempty, unique DNS labels.";
      }
      {
        assertion =
          config.networking.hostName == "blizzard" && pkgs.stdenv.hostPlatform.system == "x86_64-linux";
        message = "The Actual pilot is scoped to x86_64 Blizzard.";
      }
      {
        assertion =
          config.services.k3s.manifests == { }
          && config.services.k3s.autoDeployCharts == { }
          && config.services.k3s.charts == { }
          && config.services.k3s.images == [ ]
          && config.services.k3s.containerdConfigTemplate == null
          && (config.services.k3s.containerdConfigTemplateV3 or null) == null;
        message = "The pilot uses isolated k3s state: legacy NixOS manifest/chart/template staging must remain empty.";
      }
    ];

    services.k3s = {
      enable = true;
      role = "server";
      package = pkgs.k3s_1_35;
      nodeName = "blizzard";
      nodeIP = cfg.nodeIP;
      disable = [
        "traefik"
        "servicelb"
        "local-storage"
      ];
      configPath = "/etc/k3s-actual-pilot/config.json";
    };

    environment.etc."k3s-actual-pilot/config.json".text = builtins.toJSON {
      "data-dir" = stateDir;
      "write-kubeconfig" = kubeconfig;
      "write-kubeconfig-mode" = "0600";
      "cluster-cidr" = "10.44.0.0/16";
      "service-cidr" = "10.45.0.0/16";
      "cluster-dns" = "10.45.0.10";
      "advertise-address" = cfg.nodeIP;
      "flannel-backend" = "vxlan";
      "snapshotter" = "native";
      "kubelet-arg" = [
        "root-dir=/var/lib/kubelet-actual-pilot"
        "read-only-port=0"
      ];
      "secrets-encryption" = true;
      "private-registry" = "/etc/k3s-actual-pilot/registries.json";
      "image-credential-provider-bin-dir" = toString providerBins;
      "image-credential-provider-config" = providerConfig;
    };
    environment.etc."k3s-actual-pilot/registries.json".text = "{}";

    # Only pod -> host API and kubelet. Keep host-wide trust/rp_filter policy.
    networking.firewall.interfaces.cni0.allowedTCPPorts = [
      6443
      10250
    ];
    boot.kernelModules = [
      "br_netfilter"
      "overlay"
    ];

    environment.systemPackages = [
      pkgs.kubectl
      (pkgs.writeShellScriptBin "actual-pilot-virtctl" ''
        exec ${virtctl}/bin/virtctl --kubeconfig ${kubeconfig} "$@"
      '')
    ];

    systemd.tmpfiles.rules = [
      "d ${stateDir} 0700 root root - -"
      "d /var/lib/kubelet-actual-pilot 0700 root root - -"
      "d /etc/rancher/k3s-actual-pilot 0700 root root - -"
      "d /flash/enc/vms/kubevirt-pilot 0700 root root - -"
      "d /flash/enc/vms/kubevirt-pilot/actual 0700 root root - -"
      "d /flash/enc/vms/kubevirt-pilot/actual/root 0700 root root - -"
      "d /flash/enc/vms/kubevirt-pilot/actual/data 0700 root root - -"
    ];

    systemd.services.k3s = {
      unitConfig.RequiresMountsFor = [ "/flash/enc/vms" ];
      requires = [ "actual-pilot-firewall.service" ];
      after = [ "actual-pilot-firewall.service" ];
      # These runtime sockets are upstream-global even with a custom data-dir.
      # Refuse a first start while another/legacy runtime owns them; never clean
      # up someone else's containerd, Flannel, or old cluster state.
      preStart = ''
        ${pkgs.util-linux}/bin/mountpoint -q /flash/enc/vms || {
          echo "Actual pilot: /flash/enc/vms must be mounted before starting" >&2
          exit 1
        }
        ${python}/bin/python ${./scripts/actual_pilot_preflight.py} ${preflightPaths}
      '';
    };

    # Filter after destination NAT, before Tailscale's broad INPUT ACCEPT.
    # This also covers the API ClusterIP; fib LOCAL excludes routed traffic.
    systemd.services.actual-pilot-firewall = {
      description = "Private Actual pilot control-plane ingress guard";
      wantedBy = [ "multi-user.target" ];
      before = [ "k3s.service" ];
      after = [ "firewall.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.nftables}/bin/nft --file ${firewallRules}";
      };
    };

    systemd.services.actual-pilot-bootstrap = {
      description = "Seed missing Flux objects for the private Actual pilot";
      after = [ "k3s.service" ];
      requires = [ "k3s.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.kubectl ];
      environment.KUBECONFIG = kubeconfig;
      startLimitIntervalSec = 900;
      startLimitBurst = 3;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${python}/bin/python ${./scripts/actual_pilot_bootstrap.py} ${fluxComponents} ${sync}";
        TimeoutStartSec = 900;
        Restart = "on-failure";
        RestartSec = 30;
        CacheDirectory = "actual-pilot";
        UMask = "0077";
      };
    };
  };
}
