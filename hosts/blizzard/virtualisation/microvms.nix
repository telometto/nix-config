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
  vmUrl = name: "http://${reg.${name}.ip}:${toString reg.${name}.port}";
  immichMlProxyPort = 3003;

  localhostUrl = "http://localhost:80";

  mkPublicIngress =
    subdomains:
    builtins.listToAttrs (
      map (subdomain: {
        name = "${subdomain}.${VARS.domains.public}";
        value = localhostUrl;
      }) subdomains
    );

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
      cfTunnel.ingress = mkPublicIngress (spec.ingressHosts or [ ]) // (spec.extraIngress or { });
      reverseProxy = spec.reverseProxy or { };
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
      ingressHosts = [ "adguard" ];
    };

    actual = {
      enable = false;
      ingressHosts = [ "actual" ];
      reverseProxy = {
        subdomain = "actual";
        url = vmUrl "actual";
      };
    };

    searx = {
      enable = true;
      ingressHosts = [ "search" ];
      reverseProxy = {
        subdomain = "search";
        url = vmUrl "searx";
      };
    };

    overseerr = {
      enable = true;
      ingressHosts = [ "requests" ];
      reverseProxy = {
        subdomain = "requests";
        url = vmUrl "overseerr";
        middlewares = [
          "plex-headers"
          "crowdsec"
        ];
      };
    };

    ombi = {
      enable = false;
      ingressHosts = [ "ombi" ];
      reverseProxy = {
        subdomain = "ombi";
        url = vmUrl "ombi";
      };
    };

    tautulli = {
      enable = true;
      ingressHosts = [ "tautulli" ];
      reverseProxy = {
        subdomain = "tautulli";
        url = vmUrl "tautulli";
        middlewares = [
          "plex-headers"
          "crowdsec"
        ];
      };
    };

    gitea = {
      enable = true;
      ingressHosts = [ "git" ];
      reverseProxy = {
        subdomain = "git";
        url = vmUrl "gitea";
        middlewares = [
          "security-headers"
          "gitea-xfp-https"
          "crowdsec"
        ];
      };
    };

    sonarr = {
      enable = true;
      ingressHosts = [ "series" ];
      reverseProxy = {
        subdomain = "series";
        url = vmUrl "sonarr";
        middlewares = [
          "app-compat-headers"
          "crowdsec"
        ];
      };
    };

    radarr = {
      enable = true;
      ingressHosts = [ "movies" ];
      reverseProxy = {
        subdomain = "movies";
        url = vmUrl "radarr";
        middlewares = [
          "app-compat-headers"
          "crowdsec"
        ];
      };
    };

    prowlarr = {
      enable = true;
      ingressHosts = [ "indexer" ];
      reverseProxy = {
        subdomain = "indexer";
        url = vmUrl "prowlarr";
        middlewares = [
          "app-compat-headers"
          "crowdsec"
        ];
      };
    };

    bazarr = {
      enable = true;
      ingressHosts = [ "subs" ];
      reverseProxy = {
        subdomain = "subs";
        url = vmUrl "bazarr";
        middlewares = [
          "app-compat-headers"
          "crowdsec"
        ];
      };
    };

    readarr = {
      enable = true;
      ingressHosts = [ "books" ];
      reverseProxy = {
        subdomain = "books";
        url = vmUrl "readarr";
        middlewares = [
          "app-compat-headers"
          "crowdsec"
        ];
      };
    };

    lidarr = {
      enable = false;
      ingressHosts = [ "music" ];
    };

    qbittorrent = {
      enable = true;
      portForwards = [ (mkPortForward "tcp" 11030 null) ];
    };

    sabnzbd = {
      enable = true;
      portForwards = [ (mkPortForward "tcp" 11031 null) ];
      ingressHosts = [ "sab" ];
      reverseProxy = {
        subdomain = "sab";
        url = vmUrl "sabnzbd";
      };
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
      ingressHosts = [ "ff" ];
      reverseProxy = {
        subdomain = "ff";
        url = vmUrl "firefox";
        middlewares = [
          "firefox-headers"
          "crowdsec"
        ];
      };
    };

    brave = {
      enable = false;
      portForwards = [
        (mkPortForward "tcp" 11054 null)
        (mkPortForward "tcp" 11055 null)
      ];
      ingressHosts = [ "brave" ];
    };

    matrix-synapse = {
      enable = true;
      portForwards = [ (mkPortForward "tcp" 11060 null) ];
      ingressHosts = [ "matrix" ];
      extraIngress = {
        "${VARS.domains.public}" = localhostUrl;
      };
      reverseProxy = {
        enable = false;
        subdomain = "matrix";
        url = vmUrl "matrix-synapse";
      };
    };

    paperless = {
      enable = false;
      portForwards = [ (mkPortForward "tcp" 11061 null) ];
      ingressHosts = [ "docs" ];
      reverseProxy = {
        subdomain = "docs";
        url = vmUrl "paperless";
        middlewares = [
          "csrf-safe-headers"
          "crowdsec"
        ];
      };
    };

    firefly = {
      enable = false;
      portForwards = [ (mkPortForward "tcp" 11062 null) ];
      ingressHosts = [ "finance" ];
      reverseProxy = {
        subdomain = "finance";
        url = vmUrl "firefly";
        middlewares = [
          "firefly-headers"
          "crowdsec"
        ];
      };
    };

    "firefly-importer" = {
      enable = false;
      portForwards = [ (mkPortForward "tcp" 11063 null) ];
      ingressHosts = [ "finimport" ];
      reverseProxy = {
        subdomain = "finimport";
        url = vmUrl "firefly-importer";
        middlewares = [
          "firefly-headers"
          "crowdsec"
        ];
      };
    };

    immich = {
      enable = true;
      # Keep the VM port off the host while publishing it through the managed
      # Cloudflare Tunnel and Traefik route.
      portForwards = [ ];
      ingressHosts = [ "photos" ];
      reverseProxy = {
        enable = true;
        subdomain = "photos";
        url = vmUrl "immich";
        middlewares = [
          "immich-headers"
          "crowdsec"
        ];
      };
    };

    mealie = {
      enable = false;
      portForwards = [ (mkPortForward "tcp" 11071 null) ];
      ingressHosts = [ "recipes" ];
      reverseProxy = {
        subdomain = "recipes";
        url = vmUrl "mealie";
        middlewares = [
          "security-headers"
          "crowdsec"
        ];
      };
    };

    trigger = {
      enable = true;
      ingressHosts = [ "triggers" ];
      reverseProxy = {
        subdomain = "triggers";
        url = vmUrl "trigger";
        middlewares = [
          "trigger-headers"
          "crowdsec"
        ];
      };
    };

    "pocket-id" = {
      enable = true;
      vmConfig.restartIfChanged = true;
      ingressHosts = [ "id" ];
      reverseProxy = {
        subdomain = "id";
        url = vmUrl "pocket-id";
        middlewares = [
          "pocket-id-headers"
          "crowdsec"
        ];
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

      instances = builtins.mapAttrs mkInstance vmSpecs;
    };
  };
}
