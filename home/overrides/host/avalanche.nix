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

  programs.ghostty = {
    enable = true;

    enableZshIntegration = true;

    systemd.enable = true;

    settings = {
      font-family = "FiraCode Nerd Font Mono";
      font-size = 13;

      theme = "Pale Night Hc";

      background-opacity = 0.95;

      cursor-style = "block";
      cursor-style-blink = false;

      window-padding-x = 8;
      window-padding-y = 4;
      window-padding-balance = true;

      mouse-hide-while-typing = true;

      shell-integration = "zsh";
    };
  };

  # Laptop-specific overrides:
  # hm.programs.media.extraPackages = with pkgs; [ laptop-specific-media ];
  # programs.git.extraConfig.avalanche = "laptop-setting";
}
