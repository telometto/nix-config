{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sys.services.jellyfin;
in
{
  options.sys.services.jellyfin = {
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
  };

  config = lib.mkIf cfg.enable {
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

    environment.systemPackages = with pkgs; [
      jellyfin
      jellyfin-web
      jellyfin-ffmpeg
    ];

    environment.sessionVariables = {
      LIBVA_DRIVER_NAME = lib.mkDefault "iHD";
    };
  };
}
