{ config, lib, pkgs, ... }:

{
  programs = {
    atuin = { enable = false; };
    zsh = { enable = true; };
  };

  environment.systemPackages = with pkgs; [ zsh ];
}
