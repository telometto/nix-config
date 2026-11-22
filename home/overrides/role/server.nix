# Role-wide HM overrides for server-role hosts (applies to every HM user when sys.role.server.enable = true)
{ lib, ... }:
let
  mkRoleDefault = lib.mkOverride 900;
in
{
  imports = [ ./ssh-common.nix ];

  hm.programs = {
    browsers = {
      enable = mkRoleDefault false;
      chromium.enable = mkRoleDefault false;
    };

    gaming.enable = mkRoleDefault false;
    media.enable = mkRoleDefault false;
    social.enable = mkRoleDefault false;

    tools = {
      enable = mkRoleDefault false;
      flameshot.enable = mkRoleDefault false;
      texlive.enable = mkRoleDefault false;
      onlyoffice.enable = mkRoleDefault false;
      podman.enable = mkRoleDefault false;
    };
  };
}
