{ config, lib, pkgs, ... }:

{
  programs = {
    zsh = { enable = true; };
  };

  environment.systemPackages = with pkgs; [ zsh ];
}
