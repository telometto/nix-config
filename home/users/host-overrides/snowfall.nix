# Host-specific user overrides for snowfall
{ _ }:
{
  # Snowfall-specific user configuration
  # These settings will be applied to all users on this host

  # Example overrides:
  # hm.programs.development.extraPackages = with pkgs; [ snowfall-specific-tool ];
  # programs.git.extraConfig.snowfall = "specific-setting";
}
