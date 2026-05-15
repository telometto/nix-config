{
  config,
  lib,
  pkgs,
  VARS,
  consts,
  ...
}:
{
  # kvm-intel is already loaded via hardware-configuration.nix (Intel CPU); no override needed.

  networking = {
    hostName = lib.mkForce "blizzard";
    hostId = lib.mkForce "86bc16e3";

    firewall = {
      enable = true;

      # Required for Cilium: pod traffic arrives on veth interfaces with
      # source IPs outside the expected routing path; strict rp_filter drops it.
      checkReversePath = false;

      # Do not trust all Cilium pod veth traffic. Only open the pod→host
      # ports required for the k3s API backend and Cilium/Hubble internals.
      interfaces."lxc+".allowedTCPPorts = [
        6443 # k3s API backend after Cilium Service translation
        4240 # Cilium health check
        4244 # Hubble server
        4245 # Hubble relay
      ];

      allowedTCPPorts = [ ];
      allowedUDPPorts = [ ];
      # Note: 8472/UDP (VXLAN) is NOT opened — canonical config uses
      # routingMode: native, not VXLAN overlay.

      allowedTCPPortRanges = [ ];
      allowedUDPPortRanges = [ ];
    };
  };

  sys = {
    role.server.enable = true;

    users.zeno.enable = true;

    nix.distributedBuilds = {
      enable = true;

      buildMachines = [
        {
          hostName = "snowfall";
          systems = [ "x86_64-linux" ];
          sshUser = "zeno";
          sshKey = "/home/zeno/.ssh/nix-build-blizzard";
          maxJobs = 16;
          speedFactor = 3;
          supportedFeatures = [
            "kvm"
            "big-parallel"
            "benchmark"
          ];
        }
      ];
    };

    ## Pull specific packages from different nixpkgs inputs
    # overlays = {
    #   fromInputs = {
    #     nixpkgs-unstable = [
    #       "firefox"
    #       "discord"
    #     ];
    #     nixpkgs-stable = [ "thunderbird" ];
    #   };

    ## Add custom overlays
    #   custom = [
    #     (final: prev: {
    #       firefox = prev.firefox.override {
    #         enablePlasmaBrowserIntegration = true;
    #       };
    #     })
    #   ];
    # };

    services = {
      k3s = {
        enable = true;
        ciliumCni = true;
        bootstrap = {
          enable = true;
          ciliumValuesFile = ./virtualisation/cilium-values.yaml;
          fluxValuesFile = ./virtualisation/flux-instance-values.yaml;
          # To fully automate Flux's Git auth on first boot, add the SSH key to
          # nix-secrets, encrypt with sops, then set:
          #   fluxGitAuthSecretFile = config.sops.secrets."flux-git-auth".path;
        };
      };

      resolved = {
        enableDNS = false;
        enableFallbackDNS = true;

        enableLLMNR = true;
        LLMNR = "resolve";
      };

      tailscale = {
        interface = "enp8s0";
        openFirewall = true;

        extraUpFlags = [
          "--reset"
          "--ssh"
          "--advertise-routes=192.168.2.0/24,10.100.0.0/24"
        ];
      };
    };

    programs = {
      mtr.enable = true;
      gnupg.enable = false;
    };
  };

  services = {
    rustdesk-server = {
      enable = true;
      openFirewall = true;
      signal.relayHosts = [
        "${config.networking.hostName}.${consts.tailscale.suffix}"
      ];
    };
  };

  environment.variables.KUBECONFIG = "/home/${VARS.users.zeno.user}/.kube/config";

  systemd.services.k3s-copy-kubeconfig = {
    description = "Copy k3s kubeconfig to ${VARS.users.zeno.user} home directory";
    after = [ "k3s.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.coreutils ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "k3s-copy-kubeconfig" ''
        set -euo pipefail
        deadline=120
        elapsed=0
        while [ ! -f /etc/rancher/k3s/k3s.yaml ]; do
          if [ "$elapsed" -ge "$deadline" ]; then
            echo "k3s-copy-kubeconfig: timed out waiting for k3s.yaml" >&2
            exit 1
          fi
          sleep 2
          elapsed=$((elapsed + 2))
        done
        install -d -m 700 -o ${VARS.users.zeno.user} -g users /home/${VARS.users.zeno.user}/.kube
        install -m 600 -o ${VARS.users.zeno.user} -g users \
          /etc/rancher/k3s/k3s.yaml \
          /home/${VARS.users.zeno.user}/.kube/config
      '';
    };
  };

  systemd.tmpfiles.rules = [
    "d /flash/enc/kubevirt 0700 root root - -"
    "d /flash/enc/kubevirt/actual 0700 root root - -"
    "d /flash/enc/kubevirt/actual/rootdisk 0700 root root - -"
  ];

  system.stateVersion = "24.11";
}
