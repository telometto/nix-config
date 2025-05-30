/**
 * This NixOS module configures the Tailscale service with default settings.
 * It enables the Tailscale service, opens the firewall for Tailscale traffic,
 * and specifies the path to the Tailscale authentication key file.
 * Additionally, it ensures that the Tailscale package is included in the system environment packages.
 *
 * - authKeyFile: The path to the Tailscale authentication key file.
 */

{ config, lib, pkgs, ... }:

{
  services = {
    tailscale = {
      enable = true;

      openFirewall = true;

      authKeyFile = config.sops.secrets."general/tsKeyFilePath".path;
      authKeyParameters = {
        preauthorized = true;
        ephemeral = false;
      };

      extraUpFlags = [ "--reset" "--ssh" ];
    };

    # Snippet below is to optimize the performance of subnet routers and exit nodes
    networkd-dispatcher = {
      enable = true;

      rules."50-tailscale" = {
        onState = [ "routable" ];
        script = ''
          ${lib.getExe pkgs.ethtool} -K eth0 rx-udp-gro-forwarding on rx-gro-list off
        '';
      };
    };
  };

  sops.secrets."general/tsKeyFilePath" = { };

  environment.systemPackages = with pkgs; [
    networkd-dispatcher
    tailscale
    ethtool
  ];
}
