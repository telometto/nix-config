{
  lib,
  VARS,
  ...
}:
{
  networking = {
    hostName = lib.mkForce "blizzard";
    hostId = lib.mkForce "86bc16e3";

    firewall = rec {
      enable = true;

      allowedTCPPorts = [ ];
      allowedUDPPorts = allowedTCPPorts;

      allowedTCPPortRanges = [ ];
      allowedUDPPortRanges = allowedTCPPortRanges;
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

    overlays.fromInputs = {
      # nixpkgs-unstable = [ "intel-graphics-compiler" ];
      # nixpkgs-stable = [ "searxng" ];

      # TODO: Remove once microvm.nix adds format=raw to cloud-hypervisor disk args
      # cloud-hypervisor v51.0 blocks sector-0 writes for autodetected raw images
      # (security fix PR #7728), breaking all MicroVM volume mounts
      nixpkgs-stable-latest = [ "beets" ];
    };

    services = {
      k3s.enable = false;

      rustdesk-server = {
        enable = true;
        openFirewall = true;
        signal.relayHosts = [
          "${config.networking.hostName}.mole-delta.ts.net"
        ];
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

  environment.variables.KUBECONFIG = "/home/${VARS.users.zeno.user}/.kube/config";

  system.stateVersion = "24.11";
}
