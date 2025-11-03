{
  config,
  lib,
  VARS,
  pkgs,
  ...
}:
let
  grafanaDashboards = import ../../lib/grafana-dashboards.nix { inherit lib pkgs; };
in
{
  imports = [
    ./hardware-configuration.nix
    ./packages.nix
  ];

  networking = {
    hostName = lib.mkForce "snowfall";
    hostId = lib.mkForce "131b6b39";

    firewall = rec {
      enable = true;

      allowedTCPPorts = [ ];
      allowedUDPPorts = allowedTCPPorts;

      allowedTCPPortRanges = [ ];
      allowedUDPPortRanges = allowedTCPPortRanges;
    };
  };

  telometto = {
    role.desktop.enable = true;

    desktop.flavor = "kde";

    users.zeno.enable = true;

    programs = {
      nix-ld.enable = true;
      python-venv.enable = true;
    };

    # Pull specific packages from different nixpkgs inputs
    # overlays.fromInputs = {
    #   nixpkgs-unstable = [ "firefox" "discord" ];
    #   nixpkgs-stable = [ "thunderbird" ];
    # };
    #
    # Add custom overlays
    # overlays.custom = [
    #   (final: prev: {
    #     firefox = prev.firefox.override {
    #       enablePlasmaBrowserIntegration = true;
    #     };
    #   })
    # ];

    services = {
      tailscale = {
        interface = "enp5s0";
        openFirewall = true;
      };

      nfs = {
        enable = true;

        server = {
          enable = true;
          exports = ''
            /run/media/zeno/personal/nfs-oldie 192.168.2.0/24(rw,sync,nohide,no_subtree_check)
          '';
          openFirewall = false;
        };
      };

      prometheus = {
        enable = lib.mkDefault true;
        listenAddress = "127.0.0.1";
        openFirewall = lib.mkDefault false;
        scrapeInterval = "15s";

        extraScrapeConfigs = [
          {
            job_name = "traefik";
            static_configs = [
              {
                targets = [ "localhost:8080" ];
              }
            ];
          }
        ];
      };

      grafana = {
        enable = lib.mkDefault true;

        addr = "127.0.0.1";
        openFirewall = lib.mkDefault false;
        domain = "${config.networking.hostName}.mole-delta.ts.net";
        subPath = "/grafana";

        provision.dashboards = {
          # Community dashboards (automatically fetched from grafana.com)
          "node-exporter-full" = grafanaDashboards.community.node-exporter-full;
        };
      };

      grafanaCloud = {
        enable = true;

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
            options = [ "defaults" ];
          };

          samsung = {
            device = "e7e653c3-361c-4fb2-a65e-13fdcb1e6e25";
            mountPoint = "samsung";
            options = [
              "defaults"
              "nofail"
            ];
          };
        };
      };
    };
  };

  users.users.${VARS.users.zeno.user}.extraGroups = VARS.users.zeno.extraGroups ++ [ "openrazer" ];

  hardware = {
    cpu.amd.updateMicrocode = lib.mkDefault true;

    openrazer.enable = lib.mkDefault true;

    amdgpu.initrd.enable = lib.mkDefault true;

    graphics = {
      enable = lib.mkDefault true;
      enable32Bit = lib.mkDefault true;
    };
  };

  programs.virt-manager.enable = true;

  system.stateVersion = "24.05";
}
