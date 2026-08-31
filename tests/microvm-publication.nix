{
  blizzard,
  pkgs,
  self,
}:
let
  inherit (pkgs) lib;

  productionCfg = blizzard.config;
  productionTunnel =
    productionCfg.services.cloudflared.tunnels.${productionCfg.sys.services.cloudflared.tunnelId};
  productionHttp = productionCfg.services.traefik.dynamicConfigOptions.http;
  productionGiteaHeaders = productionHttp.middlewares."gitea-headers";
  productionPublicationHttp =
    productionCfg.services.traefik.dynamic.files.microvm-publications.settings.http;

  # Keep this inventory explicit so a production publication cannot disappear,
  # change host, lose policy middleware, or point at a different backend
  # without updating the expected contract.
  productionPublications = {
    bazarr = {
      hostname = "subs";
      middlewares = [ "app-compat-headers" ];
      backend = "http://10.100.0.23:11023";
    };
    firefox = {
      hostname = "ff";
      middlewares = [ "firefox-headers" ];
      backend = "http://10.100.0.52:11052";
    };
    gitea = {
      hostname = "git";
      middlewares = [
        "gitea-headers"
        "gitea-xfp-https"
      ];
      backend = "http://10.100.0.50:11050";
    };
    immich = {
      hostname = "photos";
      middlewares = [ "immich-headers" ];
      backend = "http://10.100.0.70:11070";
    };
    matrix-synapse = {
      hostname = "matrix";
      middlewares = [ "matrix-headers" ];
      backend = "http://10.100.0.60:11060";
    };
    overseerr = {
      hostname = "requests";
      middlewares = [ "plex-headers" ];
      backend = "http://10.100.0.40:11040";
    };
    pocket-id = {
      hostname = "id";
      middlewares = [ "pocket-id-headers" ];
      backend = "http://10.100.1.2:11081";
    };
    prowlarr = {
      hostname = "indexer";
      middlewares = [ "app-compat-headers" ];
      backend = "http://10.100.0.20:11020";
    };
    radarr = {
      hostname = "movies";
      middlewares = [ "app-compat-headers" ];
      backend = "http://10.100.0.22:11022";
    };
    readarr = {
      hostname = "books";
      middlewares = [ "app-compat-headers" ];
      backend = "http://10.100.0.24:11024";
    };
    sabnzbd = {
      hostname = "sab";
      middlewares = [ "sabnzbd-headers" ];
      backend = "http://10.100.0.31:11031";
    };
    searx = {
      hostname = "search";
      middlewares = [ "security-headers" ];
      backend = "http://10.100.0.12:11012";
    };
    sonarr = {
      hostname = "series";
      middlewares = [ "app-compat-headers" ];
      backend = "http://10.100.0.21:11021";
    };
    tautulli = {
      hostname = "tautulli";
      middlewares = [ "plex-headers" ];
      backend = "http://10.100.0.42:11042";
    };
  };

  expectedProductionPublicationHttp = {
    routers = lib.mapAttrs (name: publication: {
      rule = "Host(`${publication.hostname}.zzxyz.no`)";
      service = name;
      entryPoints = [ "web" ];
      middlewares = publication.middlewares ++ [ "crowdsec" ];
    }) productionPublications;
    services = lib.mapAttrs (_: publication: {
      loadBalancer.servers = [ { url = publication.backend; } ];
    }) productionPublications;
  };

  expectedProductionTunnelOrigins = builtins.listToAttrs (
    lib.mapAttrsToList (_: publication: {
      name = "${publication.hostname}.zzxyz.no";
      value = "http://localhost:80";
    }) productionPublications
  );
  actualProductionTunnelOrigins = builtins.listToAttrs (
    lib.mapAttrsToList (_: publication: {
      name = "${publication.hostname}.zzxyz.no";
      value = productionTunnel.ingress."${publication.hostname}.zzxyz.no";
    }) productionPublications
  );

  expectedMatrixWellKnownRouter = {
    rule = "Host(`zzxyz.no`) && PathPrefix(`/.well-known/matrix/`)";
    service = "matrix-synapse";
    entryPoints = [ "web" ];
    middlewares = [
      "matrix-headers"
      "crowdsec"
    ];
  };

  publishedQbittorrent = blizzard.extendModules {
    modules = [
      {
        sys.virtualisation.microvm.instances.qbittorrent.publication = {
          enable = true;
          hostname = "downloads-test";
        };
      }
    ];
  };

  cfg = publishedQbittorrent.config;
  tunnel = cfg.services.cloudflared.tunnels.${cfg.sys.services.cloudflared.tunnelId};
  http = cfg.services.traefik.dynamicConfigOptions.http;

  actual = {
    tunnelOrigin = tunnel.ingress."downloads-test.zzxyz.no";
    router = http.routers.qbittorrent;
    backend = http.services.qbittorrent;
  };

  expected = {
    tunnelOrigin = "http://localhost:80";
    router = {
      rule = "Host(`downloads-test.zzxyz.no`)";
      service = "qbittorrent";
      entryPoints = [ "web" ];
      middlewares = [
        "security-headers"
        "crowdsec"
      ];
    };
    backend.loadBalancer.servers = [
      { url = "http://10.100.0.30:11030"; }
    ];
  };

  disabledTarget = blizzard.extendModules {
    modules = [
      {
        sys.virtualisation.microvm.instances.actual.publication = {
          enable = true;
          hostname = "actual-test";
        };
      }
    ];
  };

  disabledTargetEvaluation = builtins.tryEval disabledTarget.config.system.build.toplevel.drvPath;

  missingTraefik = blizzard.extendModules {
    modules = [
      (
        { lib, ... }:
        {
          services.traefik.enable = lib.mkForce false;
          sys.virtualisation.microvm.instances.qbittorrent.publication = {
            enable = true;
            hostname = "downloads-test";
          };
        }
      )
    ];
  };

  missingTraefikEvaluation = builtins.tryEval missingTraefik.config.system.build.toplevel.drvPath;

  duplicateHostname = blizzard.extendModules {
    modules = [
      {
        sys.virtualisation.microvm.instances = {
          qbittorrent.publication = {
            enable = true;
            hostname = "duplicate-test";
          };
          wireguard.publication = {
            enable = true;
            hostname = "duplicate-test";
          };
        };
      }
    ];
  };

  duplicateHostnameEvaluation = builtins.tryEval duplicateHostname.config.system.build.toplevel.drvPath;

  compatibleQbittorrent = blizzard.extendModules {
    modules = [
      {
        sys.virtualisation.microvm.instances.qbittorrent.publication = {
          enable = true;
          hostname = "downloads-compatible-test";
          policy = "legacy-app-shell";
        };
      }
    ];
  };

  compatibleMiddlewares =
    compatibleQbittorrent.config.services.traefik.dynamicConfigOptions.http.routers.qbittorrent.middlewares;

  overriddenStrictPolicy = blizzard.extendModules {
    modules = [
      {
        services.traefik.publicationPolicyMiddlewares.strict = [
          "app-compat-headers"
        ];
      }
    ];
  };

  overriddenStrictPolicyEvaluation = builtins.tryEval overriddenStrictPolicy.config.system.build.toplevel.drvPath;

  missingCloudflare = blizzard.extendModules {
    modules = [
      (
        { lib, ... }:
        {
          sys.services.cloudflared.enable = lib.mkForce false;
        }
      )
    ];
  };

  missingCloudflareEvaluation = builtins.tryEval missingCloudflare.config.system.build.toplevel.drvPath;

  unknownPolicy = blizzard.extendModules {
    modules = [
      {
        sys.virtualisation.microvm.instances.qbittorrent.publication = {
          enable = true;
          hostname = "downloads-unknown-policy-test";
          policy = "does-not-exist";
        };
      }
    ];
  };

  unknownPolicyEvaluation = builtins.tryEval unknownPolicy.config.system.build.toplevel.drvPath;

  fakeFlake = self // {
    nixosConfigurations = self.nixosConfigurations // {
      "unregistered-vm" = self.nixosConfigurations.qbittorrent-vm;
    };
  };

  missingRegistryTarget = blizzard.extendModules {
    modules = [
      {
        sys.virtualisation.microvm.instances.unregistered = {
          enable = true;
          flake = fakeFlake;
          publication = {
            enable = true;
            hostname = "unregistered-test";
          };
        };
      }
    ];
  };

  missingRegistryTargetEvaluation = builtins.tryEval missingRegistryTarget.config.system.build.toplevel.drvPath;

  invalidHostname = blizzard.extendModules {
    modules = [
      {
        sys.virtualisation.microvm.instances.qbittorrent.publication = {
          enable = true;
          hostname = "downloads.alt";
        };
      }
    ];
  };

  invalidHostnameEvaluation = builtins.tryEval invalidHostname.config.system.build.toplevel.drvPath;

  invalidCanonicalDomain = blizzard.extendModules {
    modules = [
      (
        { lib, ... }:
        {
          sys.virtualisation.microvm.publication.canonicalDomain = lib.mkForce "https://not-a-domain.example";
        }
      )
    ];
  };

  invalidCanonicalDomainEvaluation = builtins.tryEval invalidCanonicalDomain.config.system.build.toplevel.drvPath;

  undefinedMiddleware = blizzard.extendModules {
    modules = [
      {
        services.traefik.publicationPolicyMiddlewares.undefined-middleware = [
          "middleware-name-typo"
        ];
        sys.virtualisation.microvm.instances.qbittorrent.publication = {
          enable = true;
          hostname = "downloads-undefined-middleware-test";
          policy = "undefined-middleware";
        };
      }
    ];
  };

  undefinedMiddlewareEvaluation = builtins.tryEval undefinedMiddleware.config.system.build.toplevel.drvPath;

  removedHostOption = blizzard.extendModules {
    modules = [
      {
        sys.virtualisation.microvm.autostart = [ "qbittorrent-vm" ];
      }
    ];
  };

  removedHostOptionEvaluation = builtins.tryEval removedHostOption.config.system.build.toplevel.drvPath;

  removedInstanceOption = blizzard.extendModules {
    modules = [
      {
        sys.virtualisation.microvm.instances.qbittorrent.cfTunnel.enable = true;
      }
    ];
  };

  removedInstanceOptionEvaluation = builtins.tryEval removedInstanceOption.config.system.build.toplevel.drvPath;

  matrixPublicationDisabled = blizzard.extendModules {
    modules = [
      (
        { lib, ... }:
        {
          sys.virtualisation.microvm.instances.matrix-synapse.publication.enable = lib.mkForce false;
        }
      )
    ];
  };

  matrixDisabledCfg = matrixPublicationDisabled.config;
  matrixDisabledTunnel =
    matrixDisabledCfg.services.cloudflared.tunnels.${matrixDisabledCfg.sys.services.cloudflared.tunnelId};
  matrixDisabledHttp = matrixDisabledCfg.services.traefik.dynamicConfigOptions.http;
  matrixDisabledPublicationHttp =
    matrixDisabledCfg.services.traefik.dynamic.files.microvm-publications.settings.http;
in
assert productionPublicationHttp == expectedProductionPublicationHttp;
assert actualProductionTunnelOrigins == expectedProductionTunnelOrigins;
assert productionHttp.routers.matrix-well-known == expectedMatrixWellKnownRouter;
assert !(builtins.hasAttr "contentSecurityPolicy" productionGiteaHeaders.headers);
assert builtins.hasAttr "X-Content-Type-Options"
  productionGiteaHeaders.headers.customResponseHeaders;
assert actual == expected;
assert !disabledTargetEvaluation.success;
assert !missingTraefikEvaluation.success;
assert !duplicateHostnameEvaluation.success;
assert
  compatibleMiddlewares == [
    "app-compat-headers"
    "crowdsec"
  ];
assert !overriddenStrictPolicyEvaluation.success;
assert !missingCloudflareEvaluation.success;
assert !unknownPolicyEvaluation.success;
assert !missingRegistryTargetEvaluation.success;
assert !invalidHostnameEvaluation.success;
assert !invalidCanonicalDomainEvaluation.success;
assert !undefinedMiddlewareEvaluation.success;
assert !removedHostOptionEvaluation.success;
assert !removedInstanceOptionEvaluation.success;
assert !(builtins.hasAttr "matrix.zzxyz.no" matrixDisabledTunnel.ingress);
assert !(builtins.hasAttr "matrix-synapse" matrixDisabledPublicationHttp.routers);
assert !(builtins.hasAttr "matrix-synapse" matrixDisabledPublicationHttp.services);
assert !(builtins.hasAttr "matrix-well-known" matrixDisabledHttp.routers);
pkgs.runCommand "microvm-publication-tests" { } "touch $out"
