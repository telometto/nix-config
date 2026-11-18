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
  configureServer =
    pkgs.writers.writePython3 "rustdesk-blizzard-config"
      {
        libraries = [ pkgs.python3Packages.tomlkit ];
      }
      ''
        import os
        from pathlib import Path
        import sys
        import tempfile

        import tomlkit

        public_key = sys.stdin.read().strip()
        if not public_key:
            raise RuntimeError("RustDesk server public key is empty")
        path = Path(sys.argv[1])
        if path.is_symlink():
            raise RuntimeError(f"Refusing to replace a symlink: {path}")
        current = path.read_text() if path.exists() else ""
        document = tomlkit.parse(current)
        document["rendezvous_server"] = "${server}:21116"
        if "options" not in document:
            document["options"] = tomlkit.table()
        document["options"].update({
            "custom-rendezvous-server": "${server}",
            "relay-server": "${server}",
            "key": public_key,
        })
        updated = tomlkit.dumps(document)
        if updated != current:
            path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
            with tempfile.NamedTemporaryFile(
                mode="w", dir=path.parent, prefix=".rustdesk-", delete=False
            ) as temporary:
                temporary.write(updated)
            try:
                os.replace(temporary.name, path)
            finally:
                Path(temporary.name).unlink(missing_ok=True)
      '';
in
{
  sys.services.rustdeskUnattended = {
    enable = true;
    package =
      inputs.nixpkgs-rustdesk.legacyPackages.${pkgs.stdenv.hostPlatform.system}.rustdesk-flutter-unattended-wayland;
  };

  # RustDesk uses separate configuration at the login screen and in the user
  # session. Merge only server settings, preserving passwords and device IDs.
  systemd.services.rustdesk = {
    serviceConfig.LoadCredential = [
      "server-key:${config.sys.secrets.rustdeskServerPublicKeyFile}"
    ];
    preStart = ''
      ${configureServer} /root/.config/rustdesk/RustDesk2.toml \
        < "$CREDENTIALS_DIRECTORY/server-key"
      ${pkgs.util-linux}/bin/runuser -u gianluca -- \
        ${configureServer} ${lib.escapeShellArg "${config.home-manager.users.gianluca.xdg.configHome}/rustdesk/RustDesk2.toml"} \
        < "$CREDENTIALS_DIRECTORY/server-key"
    '';
  };
}
