{ config, lib, pkgs, ... }:

{
  services.nginx = {
    enable = true;

    statusPage = true;
  };
}
