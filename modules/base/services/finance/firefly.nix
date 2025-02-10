{ config, lib, pkgs, ... }:

{
  services.firefly-iii = {
    enable = true;
  };
}