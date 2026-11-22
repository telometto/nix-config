{
  inputs,
  lib,
  config,
  ...
}:
let
  cfg = config.sys.services.vscode-server;
in
{
  imports = [ inputs.vscode-server.nixosModules.default ];

  options.sys.services.vscode-server.enable = lib.mkEnableOption "VS Code Server";

  config = lib.mkIf cfg.enable {
    services.vscode-server.enable = true;
  };
}
