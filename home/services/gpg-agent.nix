{ config, lib, ... }:
let
  cfg = config.hm.services.gpgAgent;
in
{
  options.hm.services.gpgAgent = {
    enable = lib.mkEnableOption "GPG Agent for home-manager";

    enableSsh = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable SSH support";
    };

    sshKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Enable SSH support";
    };

    defaultCacheTimes = lib.mkOption {
      type = lib.types.int;
      default = 34560000;
      description = "Default lock timeout";
    };
  };

  config = lib.mkIf cfg.enable {
    services.gpg-agent = {
      enable = true;

      enableSshSupport = cfg.enableSsh;
      enableExtraSocket = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      enableScDaemon = false; # Smartcard

      defaultCacheTtl = cfg.defaultCacheTimes; # 400 days
      defaultCacheTtlSsh = cfg.defaultCacheTimes; # 400 days
      maxCacheTtl = cfg.defaultCacheTimes; # 400 days
      maxCacheTtlSsh = cfg.defaultCacheTimes; # 400 days

      inherit (cfg) sshKeys;

      extraConfig = ''
        allow-preset-passphrase
      '';
    };
  };
}
