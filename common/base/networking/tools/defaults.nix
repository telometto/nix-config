{ config, lib, pkgs, ... }:

{
  programs = {
    mtr = { enable = true; }; # traceroute and ping in a single tool
  };

  environment.systemPackages = with pkgs; [ ];
}
