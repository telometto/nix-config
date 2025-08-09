# Tailscale abstraction deriving flags based on role & constants
{ lib, config, pkgs, mylib, ... }:
let
  inherit (lib) mkOption types mkIf optionalString optionals;
  cfg = config.my.tailscale;
  host = config.networking.hostName;
  baseFlags = [ "--reset" "--ssh" ];
  roleFlags = [ ]
    ++ (if mylib.isServer host && cfg.advertiseLAN then [ "--advertise-routes=${cfg.lanRouteCIDR}" ] else [ ])
    ++ (if mylib.isLaptop host && cfg.acceptRoutes then [ "--accept-routes" ] else [ ]);
  upFlags = baseFlags ++ roleFlags ++ cfg.extraUpFlags;
  authParams = { preauthorized = cfg.preauthorized; ephemeral = cfg.ephemeral; };
in
{
  options.my.tailscale = {
    enable = mkOption { type = types.bool; default = true; };
    lanRouteCIDR = mkOption { type = types.str; default = ""; };
    advertiseLAN = mkOption { type = types.bool; default = true; };
    acceptRoutes = mkOption { type = types.bool; default = true; };
    preauthorized = mkOption { type = types.bool; default = true; };
    ephemeral = mkOption { type = types.bool; default = false; };
    extraUpFlags = mkOption { type = types.listOf types.str; default = [ ]; };
    authKeySecret = mkOption { type = types.str; default = "general/tsKeyFilePath"; description = "SOPS secret name containing auth key"; };
  };

  config = mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      openFirewall = true;
      authKeyFile = config.sops.secrets.${cfg.authKeySecret}.path;
      authKeyParameters = authParams;
      extraUpFlags = upFlags;
    };
  };
}
