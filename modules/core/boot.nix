# Automatically imported
{
  lib,
  config,
  VARS,
  ...
}:
{
  boot = {
    crashDump.enable = lib.mkDefault true;

    initrd = {
      enable = lib.mkDefault true;

      systemd = {
        enable = lib.mkDefault true;

        emergencyAccess = lib.mkDefault config.sops.secrets."system/hashedPw".path;
      };
    };

    loader = {
      efi.canTouchEfiVariables = lib.mkDefault true;

      systemd-boot = {
        enable = lib.mkDefault true;
        configurationLimit = lib.mkDefault 3;
        consoleMode = lib.mkDefault "max";
      };
    };
  };
}
