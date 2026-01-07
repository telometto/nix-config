{ lib, config, ... }:
let
  cfg = config.sys.programs.ssh;
in
{
  options.sys.programs.ssh.enable = lib.mkEnableOption "SSH client defaults";
  config = lib.mkIf cfg.enable {
    programs.ssh = {
      enableAskPassword = lib.mkDefault true;
      forwardX11 = lib.mkDefault false;
      setXAuthLocation = lib.mkForce false;
    };
  };
}
