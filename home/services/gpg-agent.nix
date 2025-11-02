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
      enable = lib.mkDefault true;

      enableSshSupport = lib.mkDefault cfg.enableSsh;
      enableExtraSocket = lib.mkDefault true;
      enableBashIntegration = lib.mkDefault true;
      enableZshIntegration = lib.mkDefault true;
      enableScDaemon = lib.mkDefault false; # Smartcard

      defaultCacheTtl = lib.mkDefault cfg.defaultCacheTimes;
      defaultCacheTtlSsh = lib.mkDefault cfg.defaultCacheTimes;
      maxCacheTtl = lib.mkDefault cfg.defaultCacheTimes;
      maxCacheTtlSsh = lib.mkDefault cfg.defaultCacheTimes;

      inherit (cfg) sshKeys;

      extraConfig = lib.mkDefault ''
        allow-preset-passphrase
      '';
    };
  };
}
