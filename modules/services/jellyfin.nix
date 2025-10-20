{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.telometto.services.jellyfin;
in
{
  options.telometto.services.jellyfin = {
    enable = lib.mkEnableOption "Jellyfin service";

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall for Jellyfin";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "jellyfin";
      description = ''
        User account under which Jellyfin runs.
        Change this if you need Jellyfin to access external drives mounted by your user.
        If changed after initial installation, you must also change ownership of
        /var/lib/jellyfin and /var/cache/jellyfin.
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "jellyfin";
      description = "Group under which Jellyfin runs.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/jellyfin";
      description = "Directory where Jellyfin stores its data.";
    };

    cacheDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/cache/jellyfin";
      description = "Directory where Jellyfin stores cache and transcoding data.";
    };

    reverseProxy = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Traefik reverse proxy configuration for Jellyfin.";
      };

      pathPrefix = lib.mkOption {
        type = lib.types.str;
        default = "/jellyfin";
        description = "URL path prefix for Jellyfin.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 8096;
        description = "Port where Jellyfin listens.";
      };

      stripPrefix = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to strip the path prefix before forwarding to Jellyfin.";
      };

      extraMiddlewares = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional Traefik middlewares to apply.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable Jellyfin service with configured options
    services.jellyfin = {
      enable = true;
      inherit (cfg)
        openFirewall
        user
        group
        dataDir
        cacheDir
        ;
    };

    # Install required Jellyfin packages as per NixOS wiki
    environment.systemPackages = with pkgs; [
      jellyfin
      jellyfin-web
      jellyfin-ffmpeg
    ];

    # Set LIBVA_DRIVER_NAME for hardware acceleration
    # This will be overridden by jellyfin-gpu.nix if enabled
    environment.sessionVariables = {
      LIBVA_DRIVER_NAME = lib.mkDefault "iHD";
    };

    # Contribute to Traefik configuration if reverse proxy is enabled and Traefik is available
    telometto.services.traefik.services =
      lib.mkIf (cfg.reverseProxy.enable && config.telometto.services.traefik.enable or false)
        {
          jellyfin = {
            backendUrl = "http://localhost:${toString cfg.reverseProxy.port}/";
            pathPrefix = cfg.reverseProxy.pathPrefix;
            stripPrefix = cfg.reverseProxy.stripPrefix;
            extraMiddlewares = cfg.reverseProxy.extraMiddlewares;
            customHeaders = {
              X-Forwarded-Proto = "https";
              X-Forwarded-Host =
                config.telometto.services.traefik.domain or "${config.networking.hostName}.local";
            };
          };
        };
  };
}
