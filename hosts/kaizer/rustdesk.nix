{
  config,
  consts,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  server = "blizzard.${consts.tailscale.suffix}";
  configureServer = pkgs.writers.writePython3 "rustdesk-blizzard-config" { } (
    builtins.readFile ./rustdesk-server-config.py
  );
in
{
  sys.services.rustdeskUnattended = {
    enable = true;
    package =
      inputs.nixpkgs-rustdesk.legacyPackages.${pkgs.stdenv.hostPlatform.system}.rustdesk-flutter-unattended-wayland.overrideAttrs
        (previous: {
          patches = (previous.patches or [ ]) ++ [ ./rustdesk-managed-settings.patch ];
        });
  };

  # All client processes read the same runtime layer, including a fresh SDDM
  # greeter and independently launched GUIs. Never rewrite their profile files.
  systemd.services.rustdesk = lib.mkIf config.sys.services.rustdeskUnattended.enable {
    serviceConfig = {
      LoadCredential = [
        "server-key:${config.sys.secrets.rustdeskServerPublicKeyFile}"
      ];
      RuntimeDirectory = "rustdesk";
      RuntimeDirectoryMode = "0755";
      RuntimeDirectoryPreserve = "restart";
    };
    preStart = ''
      ${configureServer} "$RUNTIME_DIRECTORY/server-options" ${lib.escapeShellArg server} \
        < "$CREDENTIALS_DIRECTORY/server-key"
    '';
  };
}
