# Host-specific user overrides for kaizer
# These settings will be applied to all users on kaizer host
{ lib, pkgs, ... }:
{
  home.packages = [
    # RustDesk is installed system-wide by sys.services.rustdeskUnattended.
    pkgs.polychromatic # Razer configuration tool
    # pkgs.kdePackages.krdc
    pkgs.meld
    pkgs.rendercv
  ];

  hm.programs = {
    media = {
      enable = true;

      mpv.enable = true;
      yt-dlp.enable = true;
    };

    gaming.lutris.enable = lib.mkForce false;
  };
}
