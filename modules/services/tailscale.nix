{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.telometto.services.tailscale;
in
{
  options.telometto.services.tailscale = {
    enable = lib.mkEnableOption "Tailscale VPN";
    extraUpFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "--reset"
        "--ssh"
      ];
      description = "Extra flags appended to tailscale up (owner extension point).";
    };
    interface = lib.mkOption {
      type = lib.types.str;
      default = "eth0";
      description = "Network interface name for networkd-dispatcher rule (e.g., eth0, enp5s0).";
    };
    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Extra attributes merged into services.tailscale (owner extension point).";
    };
  };
  config = lib.mkIf cfg.enable {
    services = {
      tailscale = lib.mkMerge [
        {
          enable = lib.mkDefault true;
          openFirewall = lib.mkDefault true;
          # Use the project-owned secrets bridge; avoid referencing SOPS directly here
          # to prevent top-level evaluation errors when the feature is disabled.
          authKeyFile = config.telometto.secrets.tsKeyFile;
          authKeyParameters = {
            preauthorized = lib.mkDefault true;
            ephemeral = lib.mkDefault false;
          };
          inherit (cfg) extraUpFlags;
        }
        cfg.settings
      ];
      networkd-dispatcher = {
        enable = lib.mkDefault true;
        rules."50-tailscale" = {
          onState = [ "routable" ];
          script = "${lib.getExe pkgs.ethtool} -K ${cfg.interface} rx-udp-gro-forwarding on rx-gro-list off";
        };
      };
    };
  };
}
