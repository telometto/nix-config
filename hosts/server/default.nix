{ config, lib, pkgs, VARS, name, nodes, ... }:
{
  imports = [ ./configuration.nix ];

  deployment = {
    targetHost = "192.168.2.100";
    targetPort = 22;
    targetUser = myvars.users.admin.user;
    buildOnTarget = true;

    # sshOptions = [ ];
    # tags = [ ];

    keys = {
      # destDir = "";
      # group = "";
      # keyFile = "";
      # keyCommand = [ ];
    };
  };
}
