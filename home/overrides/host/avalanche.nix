# Host-specific user overrides for avalanche (laptop)
{ config, ... }:
{
  imports = [ ./ssh-common.nix ];

  # Avalanche-specific user configuration
  # These settings will be applied to all users on this host

  hm = {
    programs = {
      browsers.chromium.enable = false;
    };
  };

  # Laptop-specific overrides:
  # hm.programs.media.extraPackages = with pkgs; [ laptop-specific-media ];
  # programs.git.extraConfig.avalanche = "laptop-setting";
}
