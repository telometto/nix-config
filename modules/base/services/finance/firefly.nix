{ config, lib, pkgs, ... }:

{
  services.firefly = {
    enable = true;
  };
}