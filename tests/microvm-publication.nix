{
  blizzard,
  pkgs,
  self,
}:
let
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
in
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
pkgs.runCommand "microvm-publication-tests" { } "touch $out"
