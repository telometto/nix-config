{ lib, config, ... }:
# Namespace & layering notes:
# - This module owns options under `telometto.services.openssh.*`.
# - Other modules should not redeclare these options; they may set sub-options
#   we expose (e.g., extra settings) to avoid namespace collisions.
# - Use mkDefault in core, mkOverride in roles/features, mkForce in host overrides
#   for predictable precedence.
let
  cfg = config.telometto.services.openssh;
  defaultSettings = {
    X11Forwarding = lib.mkDefault false;
    PermitRootLogin = lib.mkDefault "no";
    PasswordAuthentication = lib.mkDefault false;
    UsePAM = lib.mkDefault true;
  };
in
{
  options.telometto.services.openssh = {
    enable = lib.mkEnableOption "Enable OpenSSH service (owner module)";
    # Extension points owned by this module; other modules can set these instead of
    # redefining the owner’s options or touching services.openssh directly.
    extraSettings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Additional OpenSSH settings to be merged with defaults.";
    };
    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Additional raw sshd_config lines appended via services.openssh.extraConfig.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.openssh = {
      enable = true;
      banner = lib.mkDefault ":: Welcome back to The Matrix! ::";
      # Merge defaults with contributed settings from other modules
      settings = lib.mkMerge [
        defaultSettings
        cfg.extraSettings
      ];
      inherit (cfg) extraConfig;
      openFirewall = lib.mkDefault false;
    };
  };
}
