{ self, VARS, ... }:
{
  sys.virtualisation = {
    enable = true;

    microvm = {
      enable = true;
      stateDir = "/rpool/unenc/vms";
      autostart = [
        "adguard-vm"
        "actual-vm"
        "searx-vm"
        "ombi-vm"
        "tautulli-vm"
        "gitea-vm"
      ];
      externalInterface = "enp8s0";

      vms = {
        adguard-vm.flake = self;
        actual-vm.flake = self;
        searx-vm.flake = self;
        ombi-vm.flake = self;
        tautulli-vm.flake = self;
        gitea-vm.flake = self;
      };

      expose = {
        adguard-vm = {
          ip = "10.100.0.10";

          portForward = {
            enable = true;
            ports = [
              {
                proto = "both";
                sourcePort = 53;
              }
              {
                proto = "tcp";
                sourcePort = 443;
              }
              {
                proto = "tcp";
                sourcePort = 853;
              }
            ];
          };

          cfTunnel = {
            enable = false;
            ingress = {
              "adguard.${VARS.domains.public}" = "http://localhost:80";
            };
          };
        };

        actual-vm = {
          ip = "10.100.0.11";

          portForward = {
            enable = false;
            ports = [ ];
          };

          cfTunnel = {
            enable = true;
            ingress = {
              "actual.${VARS.domains.public}" = "http://localhost:80";
            };
          };
        };

        searx-vm = {
          ip = "10.100.0.12";

          portForward = {
            enable = false;
            ports = [ ];
          };

          cfTunnel = {
            enable = true;
            ingress = {
              "search.${VARS.domains.public}" = "http://localhost:80";
            };
          };
        };
      };
    };
  };
}
