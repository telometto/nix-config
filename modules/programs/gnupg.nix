# OK
{ lib, config, ... }:
let cfg = config.telometto.programs.gnupg;
in {
  options.telometto.programs.gnupg.enable =
    lib.mkEnableOption "GnuPG agent with long cache TTL";
  config = lib.mkIf cfg.enable {
    programs.gnupg.agent = {
      enable = lib.mkDefault true;
      enableSSHSupport = lib.mkDefault false;
      settings = {
        default-cache-ttl = lib.mkDefault 34560000;
        max-cache-ttl = lib.mkDefault 34560000;
      };
    };
  };
}
