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

  systemd.user = {
    services.kaizer-flatpak-update-user = {
      Unit = {
        Description = "Update user Flatpak applications and runtimes";
      };

      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.flatpak}/bin/flatpak --user update -y --noninteractive";
      };
    };

    timers.kaizer-flatpak-update-user = {
      Unit = {
        Description = "Daily update of user Flatpak applications and runtimes";
      };

      Timer = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };

      Install = {
        WantedBy = [ "timers.target" ];
      };
    };
  };

  hm.programs = {
    media = {
      enable = true;

      mpv.enable = true;
      yt-dlp.enable = true;
    };

    gaming.lutris.enable = lib.mkForce false;
  };
}
