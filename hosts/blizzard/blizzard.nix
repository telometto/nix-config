{
  config,
  lib,
  VARS,
  consts,
  ...
}:
{
  boot.kernelModules = [ "kvm-amd" ];

  networking = {
    hostName = lib.mkForce "blizzard";
    hostId = lib.mkForce "86bc16e3";

    firewall = {
      enable = true;

      # Required for Cilium: pod traffic arrives on veth interfaces with
      # source IPs outside the expected routing path; strict rp_filter drops it.
      checkReversePath = false;

      # Trust all CNI/pod network interfaces so pod↔host traffic bypasses
      # the INPUT chain.
      trustedInterfaces = [ "cni+" ];

      allowedTCPPorts = [
        4240  # Cilium health check
        4244  # Hubble server
        4245  # Hubble relay
      ];
      allowedUDPPorts = [
        8472  # VXLAN (Cilium overlay, single-node loopback)
      ];

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
      k3s.enable = true;

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

  system.stateVersion = "24.11";
}
