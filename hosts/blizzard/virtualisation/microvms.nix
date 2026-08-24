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

  mkPortForward =
    proto: sourcePort: destPort:
    {
      inherit proto sourcePort;
    }
    // lib.optionalAttrs (destPort != null) {
      inherit destPort;
    };

  mkPrimaryPeer = reason: {
    primaryService = true;
    inherit reason;
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
      networkPolicy = spec.networkPolicy or { };
    };

  vmSpecs = {
    adguard = {
      enable = false;
      portForwards = [
        (mkPortForward "both" 53 null)
        (mkPortForward "tcp" 443 null)
        (mkPortForward "tcp" 853 null)
        (mkPortForward "tcp" consts.adguardPort null)
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
      networkPolicy.allowedPeers = {
        sonarr = mkPrimaryPeer "Submit approved series requests";
        radarr = mkPrimaryPeer "Submit approved movie requests";
      };
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
      networkPolicy.allowedPeers = {
        prowlarr = mkPrimaryPeer "Query Prowlarr for series indexer results";
        qbittorrent = mkPrimaryPeer "Send series downloads to qBittorrent";
        sabnzbd = mkPrimaryPeer "Send series downloads to SABnzbd";
      };
      publication = {
        enable = true;
        hostname = "series";
        policy = "legacy-app-shell";
      };
    };

    radarr = {
      enable = true;
      networkPolicy.allowedPeers = {
        prowlarr = mkPrimaryPeer "Query Prowlarr for movie indexer results";
        qbittorrent = mkPrimaryPeer "Send movie downloads to qBittorrent";
        sabnzbd = mkPrimaryPeer "Send movie downloads to SABnzbd";
      };
      publication = {
        enable = true;
        hostname = "movies";
        policy = "legacy-app-shell";
      };
    };

    prowlarr = {
      enable = true;
      networkPolicy.allowedPeers = {
        sonarr = mkPrimaryPeer "Synchronize indexers with Sonarr";
        radarr = mkPrimaryPeer "Synchronize indexers with Radarr";
        readarr = mkPrimaryPeer "Synchronize indexers with Readarr";
      };
      publication = {
        enable = true;
        hostname = "indexer";
        policy = "legacy-app-shell";
      };
    };

    bazarr = {
      enable = true;
      networkPolicy.allowedPeers = {
        sonarr = mkPrimaryPeer "Read series metadata and update subtitles";
        radarr = mkPrimaryPeer "Read movie metadata and update subtitles";
      };
      publication = {
        enable = true;
        hostname = "subs";
        policy = "legacy-app-shell";
      };
    };

    readarr = {
      enable = true;
      networkPolicy.allowedPeers = {
        prowlarr = mkPrimaryPeer "Query Prowlarr for book indexer results";
        qbittorrent = mkPrimaryPeer "Send book downloads to qBittorrent";
        sabnzbd = mkPrimaryPeer "Send book downloads to SABnzbd";
      };
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
      portForwards = [ (mkPortForward "tcp" consts.qbittorrentPort null) ];
    };

    sabnzbd = {
      enable = true;
      portForwards = [ (mkPortForward "tcp" consts.sabnzbdPort null) ];
      publication = {
        enable = true;
        hostname = "sab";
        policy = "sabnzbd-ui";
      };
    };

    wireguard = {
      enable = true;
      portForwards = [ (mkPortForward "udp" 51820 consts.wireguardPort) ];
    };

    firefox = {
      enable = true;
      portForwards = [
        (mkPortForward "tcp" consts.firefoxPort null)
        (mkPortForward "tcp" consts.firefoxHttpsPort null)
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
        (mkPortForward "tcp" consts.bravePort null)
        (mkPortForward "tcp" consts.braveHttpsPort null)
      ];
      publication = {
        hostname = "brave";
        policy = "browser-in-browser";
      };
    };

    matrix-synapse = {
      enable = true;
      publication = {
        enable = true;
        hostname = "matrix";
        policy = "matrix-compatible";
      };
    };

    paperless = {
      enable = false;
      portForwards = [ (mkPortForward "tcp" consts.paperlessPort null) ];
      publication = {
        hostname = "docs";
        policy = "csrf-compatible";
      };
    };

    firefly = {
      enable = false;
      portForwards = [ (mkPortForward "tcp" consts.fireflyPort null) ];
      publication = {
        hostname = "finance";
        policy = "firefly-proxy";
      };
    };

    "firefly-importer" = {
      enable = false;
      portForwards = [ (mkPortForward "tcp" consts.fireflyImporterPort null) ];
      publication = {
        hostname = "finimport";
        policy = "firefly-proxy";
      };
    };

    immich = {
      enable = true;
      # Keep the managed Cloudflare publication while also allowing direct
      # home-LAN access through Blizzard at TCP 11070.
      portForwards = [ (mkPortForward "tcp" consts.immichPort null) ];
      publication = {
        enable = true;
        hostname = "photos";
        policy = "immich-web";
      };
    };

    mealie = {
      enable = false;
      portForwards = [ (mkPortForward "tcp" consts.mealiePort null) ];
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
  networking.firewall.interfaces."microvm-br0".allowedTCPPorts = [ consts.immichMachineLearningPort ];

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
      ExecStart = "${lib.getExe pkgs.socat} TCP-LISTEN:${toString consts.immichMachineLearningPort},bind=10.100.0.1,reuseaddr,fork TCP:kaizer.boreal-ruler.ts.net:${toString consts.immichMachineLearningPort}";
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
      networkPolicy.mode = "enforce";

      instances = builtins.mapAttrs mkInstance vmSpecs;
    };
  };
}
