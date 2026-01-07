{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sys.services.samba;
  inherit (lib) types;

  mkShareConfig =
    _: share:
    {
      "path" = share.path;
      "read only" = if share.readOnly then "yes" else "no";
      "guest ok" = if share.guestOk then "yes" else "no";
    }
    // lib.optionalAttrs (share.validUsers != [ ]) {
      "valid users" = lib.concatStringsSep " " share.validUsers;
    }
    // lib.optionalAttrs (share.forceUser != null) {
      "force user" = share.forceUser;
    }
    // lib.optionalAttrs (share.forceGroup != null) {
      "force group" = share.forceGroup;
    }
    // share.extraConfig;

  sharesConfig = lib.mapAttrs mkShareConfig cfg.shares;
in
{
  options.sys.services.samba = {
    enable = lib.mkEnableOption "Samba file sharing service";

    openFirewall = lib.mkOption {
      type = types.bool;
      default = false;
      description = "Open firewall port 445 (SMB over TCP).";
    };

    globalSettings = lib.mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Additional global Samba settings merged into [global].";
    };

    shares = lib.mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            path = lib.mkOption {
              type = types.str;
              description = "Path to the directory to share.";
            };

            readOnly = lib.mkOption {
              type = types.bool;
              default = false;
              description = "Whether the share is read-only.";
            };

            guestOk = lib.mkOption {
              type = types.bool;
              default = false;
              description = "Allow guest (anonymous) access.";
            };

            validUsers = lib.mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "Users allowed to access the share (empty = all authenticated).";
            };

            forceUser = lib.mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Force all connections to use this user.";
            };

            forceGroup = lib.mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Force all connections to use this group.";
            };

            extraConfig = lib.mkOption {
              type = types.attrsOf types.anything;
              default = { };
              description = "Additional share-specific settings.";
            };
          };
        }
      );
      default = { };
      description = "Declarative Samba share definitions.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.samba = {
      enable = true;
      inherit (cfg) openFirewall;
      nmbd.enable = false; # No discovery needed over Tailscale
      winbindd.enable = false;

      settings = lib.mkMerge [
        {
          global = lib.mkMerge [
            {
              "security" = lib.mkDefault "user";
              "invalid users" = lib.mkDefault [ "root" ];
            }
            cfg.globalSettings
          ];
        }
        sharesConfig
      ];
    };

    environment.systemPackages = [ ];
  };
}
