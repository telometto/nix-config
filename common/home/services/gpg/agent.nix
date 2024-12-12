{ config, lib, pkgs, VARS, ... }:

{
  services.gpg-agent = {
    enable = true;

    enableSshSupport = false;
    enableExtraSocket = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableScDaemon = false; # Smartcard

    defaultCacheTtl = 34560000; # 400 days
    defaultCacheTtlSsh = 34560000; # 400 days
    maxCacheTtl = 34560000; # 400 days
    maxCacheTtlSsh = 34560000; # 400 days
  };
}
