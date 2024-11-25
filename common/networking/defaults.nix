/**
 * This NixOS module configures the OpenSSH service with specific settings.
 * It enables the OpenSSH service, sets various security and usability options,
 * and opens the firewall for SSH connections.
 *
 * - `services.openssh.enable`: Enables the OpenSSH service.
 * - `services.openssh.settings`: Configures OpenSSH settings:
 *   - `X11Forwarding`: Allows X11 forwarding (set to true).
 *   - `PermitRootLogin`: Disallows root login via SSH (set to "no").
 *   - `PasswordAuthentication`: Disables password authentication (set to false).
 * - `services.openssh.openFirewall`: Opens the firewall for SSH connections.
 */

{ config, lib, pkgs, ... }:

{
  services.openssh = {
    enable = true;

    settings = {
      X11Forwarding = false;
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      UsePAM = true;
    };

    # extraConfig = "X11UseLocalhost no";

    openFirewall = true;
  };

  programs = {
    ssh = {
      startAgent = true;
      enableAskPassword = true;
      forwardX11 = false;
      setXAuthLocation = false;

      /*
      extraConfig = ''
        Host *
          ForwardAgent yes
          AddKeysToAgent yes
          Compression yes
          ServerAliveInterval 0
          ServerAliveCountMax 3
          HashKnownHosts no
          UserKnownHostsFile ~/.ssh/known_hosts
          ControlMaster no
          ControlPath ~/.ssh/master-%r@%n:%p
          ControlPersist no
      '';
      */
    };
  };

  environment.systemPackages = with pkgs; [
    gnupg
    # xorg.xauth
  ];
}
