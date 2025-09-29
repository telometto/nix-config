{ lib, config, ... }:
let
  cfg = config.telometto.services.vscodeServer;
in
{
  options.telometto.services.vscodeServer.enable =
    lib.mkEnableOption "VS Code Server for remote editing over SSH";
  config = lib.mkIf cfg.enable {
    services.vscode-server.enable = true;
    # You can add policy via owner/extension pattern later if needed
  };
}
