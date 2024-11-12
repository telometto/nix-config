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
      X11Forwarding = true;
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };

    openFirewall = true;
  };
}
