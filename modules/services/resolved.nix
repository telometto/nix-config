# OK
{ lib, config, ... }:
let cfg = config.telometto.services.resolved or { };
in {
  options.telometto.services.resolved.enable =
    (lib.mkEnableOption "systemd-resolved") // {
      default = true;
    };
  options.telometto.services.resolved.extraSettings = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = { };
    description =
      "Extra settings merged into services.resolved (owner extension point).";
  };
  # Enable services.resolved when toggle is on (default true). Hosts can disable or override.
  config = lib.mkIf cfg.enable {
    services.resolved = lib.mkMerge [
      {
        enable = true;
        dnssec = "allow-downgrade";
        dnsovertls = "opportunistic";
        llmnr = "true";
      }
      cfg.extraSettings
    ];
  };
}
