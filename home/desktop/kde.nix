{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.hm.desktop.kde;

  sshAddKeysScript = pkgs.writeShellScript "ssh-add-keys" ''
    set -eu

    # Wait for ssh-agent socket to be available
    timeout=30
    while [ ! -S "$SSH_AUTH_SOCK" ]; do
      if [ $timeout -le 0 ]; then
        echo "SSH agent socket did not become available in time"
        exit 1
      fi
      sleep 1
      timeout=$((timeout - 1))
    done

    # Wait for kwallet to be available (reduced timeout to avoid login delays)
    # If KWallet isn't ready, keys can be added manually later
    timeout=5
    while ! ${pkgs.kdePackages.kwallet}/bin/kwallet-query -l ${cfg.kwalletName} > /dev/null 2>&1; do
      if [ $timeout -le 0 ]; then
        echo "KWallet not available yet, skipping automatic SSH key import"
        echo "Keys can be added manually with: ssh-add"
        exit 0  # Exit gracefully instead of failing
      fi
      sleep 1
      timeout=$((timeout - 1))
    done

    # Find and add all SSH private keys recursively
    # Exclude .pub files, known_hosts, and other non-key files
    find "${config.home.homeDirectory}/.ssh" -type f \
      ! -name "*.pub" \
      ! -name "known_hosts*" \
      ! -name "config" \
      ! -name "authorized_keys*" \
      ! -name "*.old" \
      ! -name "*.bak" \
      -exec grep -l "PRIVATE KEY" {} \; 2>/dev/null | while read -r key; do
      if [ -f "$key" ]; then
        # Validate the key using ssh-keygen
        if ${pkgs.openssh}/bin/ssh-keygen -l -f "$key" > /dev/null 2>&1; then
          echo "Adding key: $key"
          ${pkgs.openssh}/bin/ssh-add "$key" </dev/null || true
        else
          echo "Skipping invalid key: $key"
        fi
      fi
    done
  '';
in
{
  options.hm.desktop.kde = {
    enable = lib.mkEnableOption "KDE Plasma desktop environment configuration";

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional KDE packages to install";
    };

    extraConfig = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Additional KDE configuration";
    };

    autoImportSshKeys = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Automatically import SSH keys from ~/.ssh using KWallet on login";
    };

    kwalletName = lib.mkOption {
      type = lib.types.str;
      default = "kdewallet";
      description = ''
        Name of the KWallet to use for SSH key storage.
        Typical values are "kdewallet" (the default wallet), "default", or a custom wallet name.
        Example: "kdewallet"
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.kdePackages.kate
      pkgs.kdePackages.kdeconnect-kde
      pkgs.kdePackages.kcalc
      pkgs.kdePackages.kolourpaint
      pkgs.nomacs
    ]
    ++ cfg.extraPackages;

    xdg = {
      mimeApps = {
        enable = lib.mkDefault true;
        defaultApplicationPackages = [ pkgs.nomacs ];
        defaultApplications = {
          "image/png" = [ "org.nomacs.ImageLounge.desktop" ];
          "image/jpeg" = [ "org.nomacs.ImageLounge.desktop" ];
          "image/jpg" = [ "org.nomacs.ImageLounge.desktop" ];
          "image/webp" = [ "org.nomacs.ImageLounge.desktop" ];
          "image/gif" = [ "org.nomacs.ImageLounge.desktop" ];
        };
      };
    };

    # Set environment variables for SSH agent and KWallet integration
    home.sessionVariables = {
      SSH_ASKPASS = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";
      SSH_ASKPASS_REQUIRE = "prefer";
    };

    # Automatic SSH key import using KWallet
    systemd.user.services."ssh-add-keys" = lib.mkIf cfg.autoImportSshKeys {
      Unit = {
        Description = "Load SSH keys into the agent using KWallet";

        # Start after KDE session is ready, but don't block it
        After = [
          "graphical-session.target"
          "ssh-agent.service"
          "plasma-kwin_wayland.service"  # Wait for Wayland compositor
        ];

        Wants = [
          "ssh-agent.service"
        ];

        # Don't start if SSH_AUTH_SOCK is not set
        ConditionEnvironment = "SSH_AUTH_SOCK";
      };

      Service = {
        Type = "oneshot";
        RemainAfterExit = false;  # Don't block session startup

        # Restart on failure with backoff
        Restart = "on-failure";
        RestartSec = "5s";

        Environment = [
          "SSH_ASKPASS=${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass"
          "SSH_ASKPASS_REQUIRE=prefer"
        ];

        PassEnvironment = [
          "DISPLAY"
          "WAYLAND_DISPLAY"
          "DBUS_SESSION_BUS_ADDRESS"
          "XAUTHORITY"
          "SSH_AUTH_SOCK"
        ];

        ExecStart = sshAddKeysScript;
      };

      Install = {
        # Use wants instead of required, so it doesn't block login
        WantedBy = [ "default.target" ];
      };
    };
  };
}
