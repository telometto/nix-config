{ config, lib, pkgs, myVars, name, nodes, ... }:
{
  imports = [ ./configuration.nix ];

  deployment = {
    targetHost = "192.168.2.101";
    targetPort = 22;
    targetUser = myVars.users.admin.user;
    buildOnTarget = true;
  };
}
