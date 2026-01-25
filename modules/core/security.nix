{ lib, pkgs, config, ... }:
{
  security = {
    pam.services = {
      su.requireWheel = true;
      sshd.enableAppArmor = lib.mkIf config.services.openssh.enable (lib.mkDefault true);
    };

    apparmor = {
      enable = lib.mkDefault true;

      enableCache = lib.mkDefault true;

      killUnconfinedConfinables = lib.mkDefault false;

      packages = [
        pkgs.apparmor-profiles
      ];

      policies = {
        default-systemd = {
          state = "enforce";
          profile = ''
            include <tunables/global>

            profile default-systemd flags=(attach_disconnected,mediate_deleted) {
              include <abstractions/base>
              include <abstractions/nameservice>

              # Allow basic system access
              /etc/ld.so.cache r,
              /etc/ld.so.preload r,
              /etc/ld.so.conf r,
              /etc/ld.so.conf.d/{,**} r,

              # Nix store read access
              /nix/store/** mr,

              # Allow reading /proc for system information
              @{PROC}/sys/kernel/hostname r,
              @{PROC}/sys/kernel/ostype r,
              @{PROC}/sys/kernel/osrelease r,
            }
          '';
        };

        ping = {
          state = "enforce";
          profile = ''
            include <tunables/global>

            /run/current-system/sw/bin/ping {
              include <abstractions/base>
              include <abstractions/consoles>
              include <abstractions/nameservice>

              capability net_raw,
              capability setuid,
              network inet raw,
              network inet6 raw,

              /run/current-system/sw/bin/ping mr,
              /nix/store/*/bin/ping mr,

              # Allow reading proc for network info
              @{PROC}/sys/net/ipv4/ping_group_range r,
            }
          '';
        };
      };
    };

    polkit.enable = lib.mkDefault true;
    tpm2.enable = lib.mkDefault true;
  };
}
