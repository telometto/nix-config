{ lib, config, ... }:
{
  options.sys.networking.traefik-middlewares.enable =
    lib.mkEnableOption "shared Traefik middleware definitions"
    // {
      default = true;
    };

  config =
    lib.mkIf
      (config.sys.networking.traefik-middlewares.enable && config.services.traefik.enable or false)
      {
        services.traefik.dynamicConfigOptions.http.middlewares = {
          security-headers = {
            headers = {
              customResponseHeaders = {
                X-Content-Type-Options = "nosniff";
                X-Frame-Options = "SAMEORIGIN";
                X-XSS-Protection = "1; mode=block";
                Referrer-Policy = "no-referrer";
                Permissions-Policy = "geolocation=(), microphone=(), camera=(), payment=(), usb=(), magnetometer=(), gyroscope=(), accelerometer=(), fullscreen=(self), picture-in-picture=(self)";
              };

              contentSecurityPolicy = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self';";
            };
          };

          gitea-xfp-https = {
            headers.customRequestHeaders = {
              X-Forwarded-Proto = "https";
            };
          };
        };
      };
}
