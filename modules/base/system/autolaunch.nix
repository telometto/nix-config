{ config, lib, pkgs, VARS, ... }:

{
  systemd.services = {
    variety = {
      enable = true;

      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = config.users.users.${VARS.users.admin.user};
        Group = "";
        script = "";
      };
    };
  };
}