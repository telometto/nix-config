{ lib, config, ... }:
let
  cfg = config.sys.services.tautulli;
  traefikLib = import ../../lib/traefik.nix { inherit lib; };
in
{
  options.sys.services.tautulli = {
    enable = lib.mkEnableOption "Tautulli";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8181;
      description = "Port where Tautulli listens.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/rpool/unenc/apps/nixos/tautulli";
    };

    configFile = lib.mkOption {
      type = lib.types.str;
      default = "/rpool/unenc/apps/nixos/tautulli/config.ini";
      description = "This should be set so that config isn't reset every time the app (re)starts.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    reverseProxy = traefikLib.mkReverseProxyOptions {
      name = "tautulli";
      defaults.enable = false;
    };
  };

  config = lib.mkIf cfg.enable {
    services.tautulli = {
      enable = lib.mkDefault true;
      inherit (cfg)
        dataDir
        configFile
        openFirewall
        port
        ;
    };

    services.traefik.dynamic.files.tautulli = traefikLib.mkTraefikDynamicConfig {
      name = "tautulli";
      inherit cfg config;
      port = cfg.port;
      defaultMiddlewares = [ "tautulli-headers" ];
      extraDynamicConfig = {
        middlewares.tautulli-headers.headers = {
          customResponseHeaders = {
            X-Content-Type-Options = "nosniff";
            X-Frame-Options = "SAMEORIGIN";
            X-XSS-Protection = "1; mode=block";
            Referrer-Policy = "no-referrer-when-downgrade";
            Permissions-Policy = "geolocation=(), microphone=(), camera=(), payment=(), usb=(), magnetometer=(), gyroscope=(), accelerometer=(), fullscreen=(self), picture-in-picture=(self)";
          };
          # Relaxed CSP to allow Plex OAuth flow
          contentSecurityPolicy = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https://plex.tv https://*.plex.tv https://*.plex.direct wss://*.plex.direct; frame-src https://app.plex.tv;";
        };
      };
    };

    assertions = [
      {
        assertion = !cfg.reverseProxy.enable || cfg.reverseProxy.domain != null;
        message = "sys.services.tautulli.reverseProxy.domain must be set when reverseProxy is enabled";
      }
      {
        assertion = !cfg.reverseProxy.cfTunnel.enable || cfg.reverseProxy.enable;
        message = "sys.services.tautulli.reverseProxy.enable must be true when cfTunnel.enable is true";
      }
      (traefikLib.mkCfTunnelAssertion { name = "tautulli"; inherit cfg; })
    ];
  };
}
