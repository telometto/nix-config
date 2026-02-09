{ self, VARS, ... }:
{
  sys.virtualisation = {
    enable = true;

    microvm = {
      enable = true;

      externalInterface = "enp8s0";
      stateDir = "/rpool/unenc/vms";

      autostart = [
        "adguard-vm"
        "actual-vm"
        "searx-vm"
        "ombi-vm"
        "tautulli-vm"
        "gitea-vm"
        "sonarr-vm"
        "radarr-vm"
        "prowlarr-vm"
        "bazarr-vm"
        "readarr-vm"
      ];

      vms = {
        adguard-vm.flake = self;
        actual-vm.flake = self;
        searx-vm.flake = self;
        ombi-vm.flake = self;
        tautulli-vm.flake = self;
        gitea-vm.flake = self;
        sonarr-vm.flake = self;
        radarr-vm.flake = self;
        prowlarr-vm.flake = self;
        bazarr-vm.flake = self;
        readarr-vm.flake = self;
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
              {
                proto = "tcp";
                sourcePort = 11016;
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

        gitea-vm = {
          ip = "10.100.0.16";

          portForward = {
            enable = false;
            ports = [ ];
          };

          cfTunnel = {
            enable = true;
            ingress = {
              "git.${VARS.domains.public}" = "http://localhost:80";
              "ssh-git.${VARS.domains.public}" = "ssh://localhost:2222";
            };
          };
        };

        sonarr-vm = {
          ip = "10.100.0.17";

          portForward = {
            enable = true;
            ports = [
              {
                proto = "tcp";
                sourcePort = 11023;
              }
            ];
          };

          cfTunnel = {
            enable = true;
            ingress = {
              "series.${VARS.domains.public}" = "http://10.100.0.17:11023";
            };
          };
        };

        radarr-vm = {
          ip = "10.100.0.18";

          portForward = {
            enable = true;
            ports = [
              {
                proto = "tcp";
                sourcePort = 11024;
              }
            ];
          };

          cfTunnel = {
            enable = true;
            ingress = {
              "movies.${VARS.domains.public}" = "http://10.100.0.18:11024";
            };
          };
        };

        prowlarr-vm = {
          ip = "10.100.0.19";

          portForward = {
            enable = true;
            ports = [
              {
                proto = "tcp";
                sourcePort = 11025;
              }
            ];
          };

          cfTunnel = {
            enable = true;
            ingress = {
              "indexer.${VARS.domains.public}" = "http://10.100.0.19:11025";
            };
          };
        };

        bazarr-vm = {
          ip = "10.100.0.20";

          portForward = {
            enable = true;
            ports = [
              {
                proto = "tcp";
                sourcePort = 11026;
              }
            ];
          };

          cfTunnel = {
            enable = true;
            ingress = {
              "subs.${VARS.domains.public}" = "http://10.100.0.20:11026";
            };
          };
        };

        readarr-vm = {
          ip = "10.100.0.21";

          portForward = {
            enable = true;
            ports = [
              {
                proto = "tcp";
                sourcePort = 11027;
              }
            ];
          };

          cfTunnel = {
            enable = true;
            ingress = {
              "books.${VARS.domains.public}" = "http://10.100.0.21:11027";
            };
          };
        };

      };
    };
  };
}
