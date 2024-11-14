{ config, lib, pkgs, myVars, ... }:

{
  services = {
    gpg-agent = {
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

      sshKeys = [ "727A831B39D2FAC421617C2C203BF5C382E3B60A" ];

      # extraConfig = ''
      #   allow-preset-passphrase
      # '';
    };

    ssh-agent = { enable = true; };

    #kdeconnect.enable = true; # Plasma 5
  };
}
