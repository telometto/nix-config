# Host-specific user overrides for blizzard (server)
{ lib, ... }:
{
  # Blizzard-specific user configuration
  # These settings will be applied to all users on this host

  home = {
    stateVersion = lib.mkForce "24.11";
    # enableDebugInfo = lib.mkForce false;
    # preferXdgDirectories = lib.mkForce false;

    # Simple language defaults - can be overridden per user
    # language = {
    #   address = lib.mkForce locale;
    #   base = lib.mkForce locale;
    #   collate = lib.mkForce locale;
    #   ctype = lib.mkForce locale;
    #   measurement = lib.mkForce locale;
    #   messages = lib.mkForce locale;
    #   monetary = lib.mkForce locale;
    #   name = lib.mkForce locale;
    #   numeric = lib.mkForce locale;
    #   paper = lib.mkForce locale;
    #   telephone = lib.mkForce locale;
    #   time = lib.mkForce locale;
    # };

    # Default keyboard layout - can be overridden per user
    keyboard = {
      layout = lib.mkForce "no";
    };
  };

  # Example additional overrides:
  # hm.programs.terminal.extraPackages = with pkgs; [ server-tools ];
  # programs.git.extraConfig.blizzard = "server-setting";
}
