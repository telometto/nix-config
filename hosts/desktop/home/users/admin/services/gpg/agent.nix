{ config, lib, pkgs, VARS, ... }:

{
  services.gpg-agent = {
    sshKeys = [
      "B77831B9FEB4A078E8C0A92F5CD3DD364C2622F6"
      "42E575D7C88F6316332022D0A9472AE2951CAB47"
      "40C5082C45D9BD46357E15AA7BE343A6D068C74D"
    ];

    extraConfig = ''
      allow-preset-passphrase
    '';
  };
}
