# OK
{ lib, config, ... }:
let
  cfg = config.sys.programs.gnupg;
in
{
  options.sys.programs.gnupg = {
    enable = lib.mkEnableOption "GnuPG agent with long cache TTL";
    enableSSHSupport = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable SSH support in GPG agent";
    };
  };
  config = lib.mkIf cfg.enable {
    programs.gnupg.agent = {
      enable = lib.mkDefault true;
      inherit (cfg) enableSSHSupport;
      settings = {
        default-cache-ttl = lib.mkDefault 34560000;
        max-cache-ttl = lib.mkDefault 34560000;
      };
    };
  };
}
