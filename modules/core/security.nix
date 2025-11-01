{ lib, ... }:
{
  security = {
    apparmor.enable = lib.mkDefault true;
    polkit.enable = lib.mkDefault true;
    tpm2.enable = lib.mkDefault true;
  };
}
