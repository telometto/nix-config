{
  lib,
  VARS,
  ...
}:
let
  mylib = import ../../lib { inherit lib; };
in
{
  imports = [
    ./hardware-configuration.nix
    ./packages.nix
  ] ++ (mylib.scanPaths ./.);

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

    overlays.fromInputs = { };

    services = {
      k3s.enable = true;

      resolved.DNS = [ "10.100.0.10" ];

      tailscale = {
        interface = "enp8s0";
        openFirewall = true;

        extraUpFlags = [
          "--reset"
          "--ssh"
          "--advertise-routes=192.168.2.0/24,192.168.3.0/24"
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
