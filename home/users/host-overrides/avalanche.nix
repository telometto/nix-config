# Host-specific user overrides for avalanche (laptop)
{ ... }:
{
  # Avalanche-specific user configuration
  # These settings will be applied to all users on this host

  # Laptop-specific overrides:
  # hm.programs.media.extraPackages = with pkgs; [ laptop-specific-media ];
  # programs.git.extraConfig.avalanche = "laptop-setting";

  hm = {
    programs = {
      development.extraPackages = [
        pkgs.vscode
        # pkgs.jetbrains.idea-community-bin # disabled until lidbm issue has been solved
      ];
    };
  };
}
