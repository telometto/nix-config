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

    if [ -z "''${SSH_AUTH_SOCK:-}" ]; then
      if [ -z "''${XDG_RUNTIME_DIR:-}" ]; then
        echo "XDG_RUNTIME_DIR is not set; cannot locate SSH agent socket" >&2
        exit 1
      fi
      export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent"
    fi

    timeout=${toString cfg.sshAgentTimeout}
    while [ ! -S "$SSH_AUTH_SOCK" ]; do
      if [ $timeout -le 0 ]; then
        echo "SSH agent socket did not become available in time" >&2
        exit 1
      fi
      sleep 1
      timeout=$((timeout - 1))
    done

    timeout=${toString cfg.kwalletTimeout}
    while ! ${pkgs.kdePackages.kwallet}/bin/kwallet-query -l ${lib.escapeShellArg cfg.kwalletName} > /dev/null 2>&1; do
      if [ $timeout -le 0 ]; then
        echo "KWallet not available yet, skipping automatic SSH key import"
        echo "Keys can be added manually with: ssh-add"
        exit 0
      fi
      sleep 1
      timeout=$((timeout - 1))
    done

    # Auto-discover SSH keys: for every .pub file, import the private counterpart
    sshDir="${config.home.homeDirectory}/.ssh"
    for pubKey in "$sshDir"/*.pub; do
      [ -e "$pubKey" ] || continue
      keyName="$(basename "$pubKey" .pub)"
      privKey="$sshDir/$keyName"
      ${lib.optionalString (cfg.excludeKeys != [ ]) ''
        skip=0
        for excl in ${lib.escapeShellArgs cfg.excludeKeys}; do
          [ "$keyName" = "$excl" ] && skip=1 && break
        done
        [ "$skip" = "1" ] && continue
      ''}
      [ -f "$privKey" ] || continue
      if ${pkgs.openssh}/bin/ssh-keygen -l -f "$privKey" > /dev/null 2>&1; then
        echo "Adding key: $privKey"
        ${pkgs.openssh}/bin/ssh-add "$privKey" </dev/null || true
      else
        echo "Skipping invalid key: $privKey"
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

    excludeKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "SSH key filenames in ~/.ssh to skip during auto-import (base name without .pub extension).";
      example = [
        "id_ed25519"
        "work_rsa"
      ];
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

    sshAgentTimeout = lib.mkOption {
      type = lib.types.ints.positive;
      default = 30;
      description = "Seconds to wait for the SSH agent socket before failing.";
    };

    kwalletTimeout = lib.mkOption {
      type = lib.types.ints.positive;
      default = 30;
      description = "Seconds to wait for KWallet before skipping automatic SSH key import.";
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

    # Automatic SSH key import: auto-discovers private keys by .pub counterpart
    systemd.user.services."ssh-add-keys" = {
      Unit = {
        Description = "Load SSH keys into the agent using KWallet";

        After = [
          "graphical-session.target"
          "ssh-agent.service"
        ];

        Wants = [
          "ssh-agent.service"
        ];
      };

      Service = {
        Type = "oneshot";
        RemainAfterExit = false;

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
          "XDG_RUNTIME_DIR"
        ];

        ExecStart = sshAddKeysScript;
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
