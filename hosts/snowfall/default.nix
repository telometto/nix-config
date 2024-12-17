{ config, lib, pkgs, VARS, name, nodes, ... }:
{
  imports = [ ./configuration.nix ];

  deployment = {
    targetHost = "192.168.2.101";
    targetPort = 22;
    targetUser = VARS.users.admin.user;
    buildOnTarget = true;
  };
}
