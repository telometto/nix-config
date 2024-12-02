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

      # sshKeys = [ ];

      extraConfig = ''
        allow-preset-passphrase
      '';
    };

    ssh-agent = { enable = true; };

    #kdeconnect.enable = true; # Plasma 5
  };
}
