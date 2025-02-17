{ config, lib, pkgs, VARS, ... }:

{
  services.ssh-agent = { enable = false; };
}
