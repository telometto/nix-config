{ self, VARS, ... }:
{
  sys.virtualisation = {
    enable = true;

    microvm = {
      enable = true;

      externalInterface = "enp8s0";
      stateDir = "/rpool/unenc/vms";

      autostart = [
        # "adguard-vm"
        "actual-vm"
        "searx-vm"
        "overseerr-vm"
        "ombi-vm"
        "tautulli-vm"
        "gitea-vm"
        "sonarr-vm"
        "radarr-vm"
        "prowlarr-vm"
        "bazarr-vm"
        "readarr-vm"
        # "lidarr-vm" # disabled for now
        "qbittorrent-vm"
        "sabnzbd-vm"
        "wireguard-vm"
        "firefox-vm"
        # "brave-vm"
        "matrix-synapse-vm"
      ];

      vms = {
        # adguard-vm.flake = self;
        actual-vm.flake = self;
        searx-vm.flake = self;
        overseerr-vm.flake = self;
        ombi-vm.flake = self;
        tautulli-vm.flake = self;
        gitea-vm.flake = self;
        sonarr-vm.flake = self;
        radarr-vm.flake = self;
        prowlarr-vm.flake = self;
        bazarr-vm.flake = self;
        readarr-vm.flake = self;
        # lidarr-vm.flake = self;
        qbittorrent-vm.flake = self;
        sabnzbd-vm.flake = self;
        wireguard-vm.flake = self;
        firefox-vm.flake = self;
        # brave-vm.flake = self;
        matrix-synapse-vm.flake = self;
      };

      expose = {
        # adguard-vm = {
        #   ip = "10.100.0.10";
        #
        #   portForward = {
        #     enable = true;
        #     ports = [
        #       {
        #         proto = "both";
        #         sourcePort = 53;
        #       }
        #       {
        #         proto = "tcp";
        #         sourcePort = 443;
        #       }
        #       {
        #         proto = "tcp";
        #         sourcePort = 853;
        #       }
        #       {
        #         proto = "tcp";
        #         sourcePort = 11010;
        #       }
        #     ];
        #   };
        #
        #   cfTunnel = {
        #     enable = false;
        #     ingress = {
        #       "adguard.${VARS.domains.public}" = "http://localhost:80";
        #     };
        #   };
        # };

        actual-vm = {
          ip = "10.100.0.51";

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

        overseerr-vm = {
          ip = "10.100.0.40";

          portForward = {
            enable = false;
            ports = [ ];
          };

          cfTunnel = {
            enable = true;
            ingress = {
              "requests.${VARS.domains.public}" = "http://localhost:80";
            };
          };
        };

        gitea-vm = {
          ip = "10.100.0.50";

          portForward = {
            enable = false;
            ports = [ ];
          };

          cfTunnel = {
            enable = true;
            ingress = {
              "git.${VARS.domains.public}" = "http://localhost:80";
              "ssh-git.${VARS.domains.public}" = "ssh://10.100.0.50:2222";
            };
          };
        };

        ombi-vm = {
          ip = "10.100.0.41";

          portForward = {
            enable = false;
            ports = [ ];
          };

          cfTunnel = {
            enable = true;
            ingress = {
              "ombi.${VARS.domains.public}" = "http://localhost:80";
            };
          };
        };

        tautulli-vm = {
          ip = "10.100.0.42";

          portForward = {
            enable = false;
            ports = [ ];
          };

          cfTunnel = {
            enable = true;
            ingress = {
              "tautulli.${VARS.domains.public}" = "http://localhost:80";
            };
          };
        };

        sonarr-vm = {
          ip = "10.100.0.21";

          portForward = {
            enable = false;
            ports = [ ];
          };

          cfTunnel = {
            enable = true;
            ingress = {
              "series.${VARS.domains.public}" = "http://localhost:80";
            };
          };
        };

        radarr-vm = {
          ip = "10.100.0.22";

          portForward = {
            enable = false;
            ports = [ ];
          };

          cfTunnel = {
            enable = true;
            ingress = {
              "movies.${VARS.domains.public}" = "http://localhost:80";
            };
          };
        };

        prowlarr-vm = {
          ip = "10.100.0.20";

          portForward = {
            enable = false;
            ports = [ ];
          };

          cfTunnel = {
            enable = true;
            ingress = {
              "indexer.${VARS.domains.public}" = "http://localhost:80";
            };
          };
        };

        bazarr-vm = {
          ip = "10.100.0.23";

          portForward = {
            enable = false;
            ports = [ ];
          };

          cfTunnel = {
            enable = true;
            ingress = {
              "subs.${VARS.domains.public}" = "http://localhost:80";
            };
          };
        };

        readarr-vm = {
          ip = "10.100.0.24";

          portForward = {
            enable = false;
            ports = [ ];
          };

          cfTunnel = {
            enable = true;
            ingress = {
              "books.${VARS.domains.public}" = "http://localhost:80";
            };
          };
        };

        # lidarr is disabled for now
        # lidarr-vm = {
        #   ip = "10.100.0.26";

        #   portForward = {
        #     enable = false;
        #     ports = [ ];
        #   };

        #   cfTunnel = {
        #     enable = true;
        #     ingress = {
        #       "music.${VARS.domains.public}" = "http://localhost:80";
        #     };
        #   };
        # };

        qbittorrent-vm = {
          ip = "10.100.0.30";

          portForward = {
            enable = false;
            ports = [ ];
          };

          cfTunnel = {
            enable = false;
            ingress = {
              "torrent.${VARS.domains.public}" = "http://localhost:80";
            };
          };
        };

        sabnzbd-vm = {
          ip = "10.100.0.31";

          portForward = {
            enable = true;
            ports = [
              {
                proto = "tcp";
                sourcePort = 11031;
              }
            ];
          };

          cfTunnel = {
            enable = true;
            ingress = {
              "sab.${VARS.domains.public}" = "http://localhost:80";
            };
          };
        };

        wireguard-vm = {
          ip = "10.100.0.11";

          portForward = {
            enable = true;
            ports = [
              {
                proto = "udp";
                sourcePort = 51820;
                destPort = 56943;
              }
            ];
          };
        };

        firefox-vm = {
          ip = "10.100.0.52";

          portForward = {
            enable = true;
            ports = [
              {
                proto = "tcp";
                sourcePort = 11052;
              }
              {
                proto = "tcp";
                sourcePort = 11053;
              }
            ];
          };

          cfTunnel = {
            enable = true;
            ingress = {
              "ff.${VARS.domains.public}" = "http://localhost:80";
            };
          };
        };

        matrix-synapse-vm = {
          ip = "10.100.0.60";

          portForward = {
            enable = false;
            ports = [ ];
          };

          cfTunnel = {
            enable = true;
            ingress = {
              "matrix.${VARS.domains.public}" = "http://localhost:80";
            };
          };
        };

        # brave-vm = {
        #   ip = "10.100.0.54";

        #   portForward = {
        #     enable = true;
        #     ports = [
        #       {
        #         proto = "tcp";
        #         sourcePort = 11054;
        #       }
        #       {
        #         proto = "tcp";
        #         sourcePort = 11055;
        #       }
        #     ];
        #   };

        #   cfTunnel = {
        #     enable = true;
        #     ingress = {
        #       "brave.${VARS.domains.public}" = "http://localhost:80";
        #     };
        #   };
        # };

      };
    };
  };
}
