{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sys.programs.gaming;
in
{
  options.sys.programs.gaming = {
    enable = lib.mkEnableOption "Gaming stack (gamescope, steam, gamemode)";

    steam = {
      enable = lib.mkEnableOption "Enable Steam";

      openSteamLanPorts = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to enable LAN ports for Steam.";
      };
    };

    openWc3Ports = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to forward Wc3 ports";
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.steam-hardware.enable = lib.mkDefault true;

    programs = {
      gamescope = {
        enable = lib.mkDefault true;
        capSysNice = lib.mkDefault true;
      };

      steam = lib.mkIf cfg.steam.enable {
        enable = lib.mkDefault true;
        extest.enable = lib.mkDefault true;
        protontricks.enable = lib.mkDefault true;
        gamescopeSession.enable = lib.mkDefault true;
        extraPackages = with pkgs; [
          steam-run
          sc-controller # Replaced deprecated steamcontroller
          steamtinkerlaunch
          protonplus
        ];
      };
      gamemode.enable = lib.mkDefault true;

      appimage = {
        enable = lib.mkDefault true;
        binfmt = lib.mkDefault true;
      };
    };

    networking.firewall = lib.mkMerge [
      (lib.mkIf cfg.steam.openSteamLanPorts (rec {
        allowedTCPPorts = [ 27040 ];
        allowedUDPPorts = allowedTCPPorts;

        allowedTCPPortRanges = [
          {
            from = 27031;
            to = 27036;
          }
        ];
        allowedUDPPortRanges = allowedTCPPortRanges;
      }))

      (lib.mkIf cfg.openWc3Ports (rec {
        allowedTCPPortRanges = [
          {
            from = 6112;
            to = 6119;
          }
        ];
        allowedUDPPortRanges = allowedTCPPortRanges;
      }))
    ];
  };
}
