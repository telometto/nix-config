{
  self,
  VARS,
  lib,
  pkgs,
  consts,
  ...
}:
let
  reg = import ../../../vms/vm-registry.nix;
  immichMlProxyPort = 3003;

  mkPortForward =
    proto: sourcePort: destPort:
    {
      inherit proto sourcePort;
    }
    // lib.optionalAttrs (destPort != null) {
      inherit destPort;
    };

  mkInstance =
    name: spec:
    {
      flake = self;
      inherit (reg.${name}) ip;
    }
    // lib.optionalAttrs (spec ? enable) { inherit (spec) enable; }
    // {
      vmConfig = spec.vmConfig or { };
      portForward.ports = spec.portForwards or [ ];
      publication = spec.publication or { };
    };

  vmSpecs = {
    adguard = {
      enable = false;
      portForwards = [
        (mkPortForward "both" 53 null)
        (mkPortForward "tcp" 443 null)
        (mkPortForward "tcp" 853 null)
        (mkPortForward "tcp" 11010 null)
      ];
      publication.hostname = "adguard";
    };

    actual = {
      enable = false;
      publication.hostname = "actual";
    };

    searx = {
      enable = true;
      publication = {
        enable = true;
        hostname = "search";
      };
    };

    overseerr = {
      enable = true;
      publication = {
        enable = true;
        hostname = "requests";
        policy = "plex-compatible";
      };
    };

    ombi = {
      enable = false;
      publication.hostname = "ombi";
    };

    tautulli = {
      enable = true;
      publication = {
        enable = true;
        hostname = "tautulli";
        policy = "plex-compatible";
      };
    };

    gitea = {
      enable = true;
      publication = {
        enable = true;
        hostname = "git";
        policy = "strict-forwarded-https";
      };
    };

    sonarr = {
      enable = true;
      publication = {
        enable = true;
        hostname = "series";
        policy = "legacy-app-shell";
      };
    };

    radarr = {
      enable = true;
      publication = {
        enable = true;
        hostname = "movies";
        policy = "legacy-app-shell";
      };
    };

    prowlarr = {
      enable = true;
      publication = {
        enable = true;
        hostname = "indexer";
        policy = "legacy-app-shell";
      };
    };

    bazarr = {
      enable = true;
      publication = {
        enable = true;
        hostname = "subs";
        policy = "legacy-app-shell";
      };
    };

    readarr = {
      enable = true;
      publication = {
        enable = true;
        hostname = "books";
        policy = "legacy-app-shell";
      };
    };

    lidarr = {
      enable = false;
      publication = {
        hostname = "music";
        policy = "legacy-app-shell";
      };
    };

    qbittorrent = {
      enable = true;
      portForwards = [ (mkPortForward "tcp" 11030 null) ];
    };

    sabnzbd = {
      enable = true;
      portForwards = [ (mkPortForward "tcp" 11031 null) ];
      publication = {
        enable = true;
        hostname = "sab";
        policy = "sabnzbd-ui";
      };
    };

    metube = {
      enable = true;
      portForwards = [ (mkPortForward "tcp" 11072 null) ];
    };

    wireguard = {
      enable = true;
      portForwards = [ (mkPortForward "udp" 51820 56943) ];
    };

    firefox = {
      enable = true;
      portForwards = [
        (mkPortForward "tcp" 11052 null)
        (mkPortForward "tcp" 11053 null)
      ];
      publication = {
        enable = true;
        hostname = "ff";
        policy = "browser-in-browser";
      };
    };

    brave = {
      enable = false;
      portForwards = [
        (mkPortForward "tcp" 11054 null)
        (mkPortForward "tcp" 11055 null)
      ];
      publication = {
        hostname = "brave";
        policy = "browser-in-browser";
      };
    };

    matrix-synapse = {
      enable = true;
      portForwards = [ (mkPortForward "tcp" 11060 null) ];
      publication = {
        enable = true;
        hostname = "matrix";
        policy = "matrix-compatible";
      };
    };

    paperless = {
      enable = false;
      portForwards = [ (mkPortForward "tcp" 11061 null) ];
      publication = {
        hostname = "docs";
        policy = "csrf-compatible";
      };
    };

    firefly = {
      enable = false;
      portForwards = [ (mkPortForward "tcp" 11062 null) ];
      publication = {
        hostname = "finance";
        policy = "firefly-proxy";
      };
    };

    "firefly-importer" = {
      enable = false;
      portForwards = [ (mkPortForward "tcp" 11063 null) ];
      publication = {
        hostname = "finimport";
        policy = "firefly-proxy";
      };
    };

    immich = {
      enable = true;
      # Keep the managed Cloudflare publication while also allowing direct
      # home-LAN access through Blizzard at TCP 11070.
      portForwards = [ (mkPortForward "tcp" 11070 null) ];
      publication = {
        enable = true;
        hostname = "photos";
        policy = "immich-web";
      };
    };

    mealie = {
      enable = false;
      portForwards = [ (mkPortForward "tcp" 11071 null) ];
      publication.hostname = "recipes";
    };

    trigger = {
      enable = false;
      publication = {
        hostname = "triggers";
        policy = "dynamic-app-shell";
      };
    };

    "pocket-id" = {
      enable = true;
      vmConfig.restartIfChanged = true;
      publication = {
        enable = true;
        hostname = "id";
        policy = "oidc-provider";
      };
    };
  };
in
{
  networking.firewall.interfaces."microvm-br0".allowedTCPPorts = [ immichMlProxyPort ];

  systemd.services.immich-ml-proxy = {
    description = "Proxy Immich MicroVM machine-learning requests to Kaizer";
    after = [
      "network-online.target"
      "systemd-networkd.service"
      "tailscaled.service"
    ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = "${lib.getExe pkgs.socat} TCP-LISTEN:${toString immichMlProxyPort},bind=10.100.0.1,reuseaddr,fork TCP:kaizer.boreal-ruler.ts.net:${toString immichMlProxyPort}";
      Restart = "always";
      RestartSec = "5s";
      DynamicUser = true;
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
    };
  };

  sys.virtualisation = {
    enable = true;

    microvm = {
      enable = true;

      externalInterface = "enp8s0";
      stateDir = "/flash/enc/vms";
      publication.canonicalDomain = VARS.domains.public;

      instances = builtins.mapAttrs mkInstance vmSpecs;
    };
  };
}
