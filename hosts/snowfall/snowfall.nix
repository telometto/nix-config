{ lib, VARS, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./packages.nix
  ];

  networking = {
    hostName = lib.mkForce "snowfall";
    hostId = lib.mkForce "131b6b39";
  };

  telometto = {
    role.desktop.enable = true;

    desktop.flavor = "kde";

    networking = {
      firewall = {
        extraTCPPortRanges = [
          {
            from = 1714;
            to = 1764;
          }
        ];
        extraUDPPortRanges = [
          {
            from = 1714;
            to = 1764;
          }
        ];
      };
    };

    services = {
      tailscale.interface = "enp5s0";

      nfs = {
        enable = true;
        server = {
          enable = true;
          exports = ''
            /run/media/zeno/personal/nfs-oldie 192.168.2.0/24(rw,sync,nohide,no_subtree_check)
          '';
          openFirewall = true;
        };
      };

      # Testing Prometheus and Grafana setup
      prometheus = {
        enable = lib.mkDefault true; # Set to true to test
        listenAddress = "0.0.0.0"; # Listen on all interfaces (including Tailscale)
        openFirewall = lib.mkDefault false; # Firewall handled by Tailscale, no need to open public ports
        scrapeInterval = "15s";
      };

      grafana = {
        enable = lib.mkDefault true; # Set to true to test
        addr = "0.0.0.0"; # Listen on all interfaces (including Tailscale)
        openFirewall = lib.mkDefault false; # Firewall handled by Tailscale
        domain = "snowfall.mole-delta.ts.net";

        # Declaratively provision dashboards
        provision.dashboards = {
          "node-exporter-full" = ./dashboards/node-exporter-full.json;
        };
      };

      grafanaCloud = {
        enable = true;
        # Replace with your actual Grafana Cloud instance ID and URL
        # These are not secret values - they identify your Grafana Cloud instance
        # NB! DO NOT PUT THE API-KEY HERE!
        username = "2710025";
        remoteWriteUrl = "https://prometheus-prod-39-prod-eu-north-0.grafana.net/api/prom/push";
      };
    };

    storage = {
      filesystems = {
        enable = true;

        mounts = {
          personal = {
            device = "76177a35-e3a1-489f-9b21-88a38a0c1d3e";
            mountPoint = "personal";
            options = [ "defaults" ]; # Primary drive - no nofail
          };

          samsung = {
            device = "e7e653c3-361c-4fb2-a65e-13fdcb1e6e25";
            mountPoint = "samsung";
            options = [
              "defaults"
              "nofail"
            ]; # Secondary drive - with nofail
          };
        };

        # autoScrub.enable = true by default
        # autoScrub.interval = "weekly" by default
      };
    };
  };

  # Home Manager profiles are generated automatically. Override via telometto.home users when needed.

  # Add openrazer group to admin user for Razer device support
  users.users.${VARS.users.admin.user}.extraGroups = VARS.users.admin.extraGroups ++ [ "openrazer" ];

  hardware = {
    cpu.amd.updateMicrocode = lib.mkDefault true;
    openrazer.enable = lib.mkDefault true;
    amdgpu.initrd.enable = lib.mkDefault true;
    graphics = {
      enable = lib.mkDefault true;
      enable32Bit = lib.mkDefault true;
    };
  };

  # Additional services
  programs.virt-manager.enable = true;

  # System version
  system.stateVersion = "24.05";
}
