{ config, lib, pkgs, VARS, ... }:

{
  imports = [
    # Common imports
    ../../../../../common/home/imports.nix

    # Secrets
    ../../../../../common/home/security/secrets/sops-home.nix

    # Desktop environments
    # ../../../../../common/home/desktop-environments/gnome/defaults.nix # Enables GNOME
    # ../../../../../common/home/desktop-environments/hyprland/defaults.nix # Enables Hyprland
    # ../../../../../common/home/desktop-environments/kde/defaults.nix # Enables KDE

    # User-specific imports
    ./programs/programs.nix
    ./services/gpg/agent.nix
    ./services/gpg/keyring.nix
  ];

  users.users.${VARS.users.admin.user} = {
    description = VARS.users.admin.description;
    isNormalUser = VARS.users.admin.isNormalUser;
    extraGroups = VARS.users.admin.extraGroups;
    hashedPassword = VARS.users.admin.hashedPassword;
    shell = pkgs.zsh;

    openssh.authorizedKeys.keys = [
      VARS.users.admin.sshPubKey
      VARS.users.admin.gpgSshPubKey
    ];
  };

  programs.home-manager.enable = true;

  home = {
    username = VARS.users.admin.user; # Change this back upon reformatting
    stateVersion = "24.11";

    packages = with pkgs; [
      # Your packages here
      atuin
      #blesh
      sqlite
      zsh-powerlevel10k
    ];
  };
}
