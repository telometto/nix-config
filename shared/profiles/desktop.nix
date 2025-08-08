# Desktop profile: consolidates desktop-specific services and programs
{ config, lib, pkgs, VARS, mylib, ... }:
{
  # Hardware defaults
  hardware.steam-hardware.enable = lib.mkDefault true;

  # Audio for desktop systems
  services.pipewire = {
    enable = lib.mkDefault true;
    pulse.enable = lib.mkDefault true;
    jack.enable = lib.mkDefault false;
    alsa = {
      enable = lib.mkDefault true;
      support32Bit = lib.mkDefault true;
    };
  };

  # Gaming and virtualization UX (DE-specific bits live in their DE modules)
  programs = {
    steam = {
      enable = lib.mkDefault true;
      extest.enable = lib.mkDefault true;
      protontricks.enable = lib.mkDefault true;
      gamescopeSession.enable = lib.mkDefault true;
      extraPackages = with pkgs; [ steamcontroller steamtinkerlaunch ];
    };

    gamescope = {
      enable = lib.mkDefault true;
      capSysNice = lib.mkDefault true;
    };

    gamemode.enable = lib.mkDefault true;

    virt-manager.enable = lib.mkDefault true;
  };

  # Libvirt daemon for virt-manager
  virtualisation.libvirtd.enable = lib.mkDefault true;
}
