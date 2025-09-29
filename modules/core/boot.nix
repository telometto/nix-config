# Automatically imported
{
  lib,
  config,
  VARS,
  ...
}:
{
  boot = {
    initrd = {
      enable = lib.mkDefault true;

      systemd = {
        enable = lib.mkDefault true;

        emergencyAccess = lib.mkDefault config.users.users.${VARS.users.admin.user}.hashedPassword;
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
