{ lib, config, ... }:
let
  cfg = config.sys.programs.ssh;
in
{
  options.sys.programs.ssh = {
    enable = lib.mkEnableOption "SSH client defaults";

    startAgent = lib.mkOption {
      enable = lib.types.bool;
      default = true;
      description = "Whether to enable ssh-agent for system (not user)";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.ssh = {
      enableAskPassword = lib.mkDefault true;
      forwardX11 = lib.mkDefault false;
      setXAuthLocation = lib.mkForce false;
      inherit (cfg) startAgent;
    };
  };
}
