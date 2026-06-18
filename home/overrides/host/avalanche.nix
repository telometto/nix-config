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

  # Laptop-specific override examples (add pkgs to args if using packages):
  # hm.programs.media.extraPackages = with pkgs; [ vlc ];
  # programs.git.extraConfig.url."git@github.com:".insteadOf = "https://github.com/";
}
