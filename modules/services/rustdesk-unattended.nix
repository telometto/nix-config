{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.sys.services.rustdeskUnattended;
in
{
  options.sys.services.rustdeskUnattended = {
    enable = lib.mkEnableOption "RustDesk unattended Wayland desktop access, including the login screen";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.rustdesk-flutter;
      defaultText = lib.literalExpression "pkgs.rustdesk-flutter";
      description = "RustDesk client package used by the unattended service.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    boot.kernelModules = [ "uinput" ];
    security.sudo.enable = true;

    systemd.services.rustdesk = {
      description = "RustDesk unattended Wayland desktop access";
      wantedBy = [ "multi-user.target" ];
      requires = [ "network.target" ];
      after = [
        "network.target"
        "systemd-user-sessions.service"
      ];
      path = [ pkgs.gawk ];
      environment = {
        PULSE_LATENCY_MSEC = "60";
        PIPEWIRE_LATENCY = "1024/48000";
      };
      serviceConfig = {
        Type = "simple";
        User = "root";
        ExecStart = "${lib.getExe cfg.package} --service";
        Restart = "on-failure";
        RestartSec = "5s";
        # Stop session children in this unit too, without global process matching.
        KillMode = "control-group";
        TimeoutStopSec = 30;
        LimitNOFILE = 100000;
      };
    };
  };
}
