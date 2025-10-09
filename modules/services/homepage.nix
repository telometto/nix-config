{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.telometto.services.homepage;
in
{
  options.telometto.services.homepage = {
    enable = lib.mkEnableOption "Homepage Dashboard";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8082;
      description = "Port for the homepage dashboard";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open firewall for homepage dashboard";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Homepage dashboard settings";
    };

    services = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [ ];
      description = "Services to display on the homepage";
    };

    widgets = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [ ];
      description = "Widgets to display on the homepage";
    };

    bookmarks = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [ ];
      description = "Bookmarks to display on the homepage";
    };
  };

  config = lib.mkIf cfg.enable {
    services.homepage-dashboard = {
      enable = true;
      listenPort = cfg.port;
      openFirewall = cfg.openFirewall;

      settings = lib.mkDefault (
        cfg.settings
        // {
          title = lib.mkDefault "Home Server Dashboard";
          theme = lib.mkDefault "dark";
          color = lib.mkDefault "slate";
          headerStyle = lib.mkDefault "boxed";
          hideVersion = lib.mkDefault false;
        }
      );

      services = lib.mkIf (cfg.services != [ ]) cfg.services;
      widgets = lib.mkIf (cfg.widgets != [ ]) cfg.widgets;
      bookmarks = lib.mkIf (cfg.bookmarks != [ ]) cfg.bookmarks;
    };

    # Open firewall if enabled
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}
