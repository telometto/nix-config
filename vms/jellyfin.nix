{
  consts,
  jellyfinSettings,
  lib,
  pkgs,
  ...
}:
let
  reg = (import ./vm-registry.nix { inherit consts; }).jellyfin;
  gpu = jellyfinSettings.gpuPassthrough;
  libraryPath = "/rpool/unenc/media/data/media";
  migrationScript = pkgs.writeShellScriptBin "jellyfin-import-state" ''
    set -euo pipefail
    umask 077

    if ${pkgs.systemd}/bin/systemctl is-active --quiet jellyfin.service; then
      echo "Stop guest Jellyfin before importing state" >&2
      exit 1
    fi
    ${pkgs.util-linux}/bin/findmnt --mountpoint /mnt/host-jellyfin >/dev/null
    ${pkgs.util-linux}/bin/findmnt --mountpoint /var/lib/jellyfin >/dev/null

    ${pkgs.rsync}/bin/rsync -aH --delete --chown=jellyfin:jellyfin \
      /mnt/host-jellyfin/ /var/lib/jellyfin/
    differences=$(${pkgs.rsync}/bin/rsync -aHnc --no-owner --no-group --delete \
      --out-format='%i %n' /mnt/host-jellyfin/ /var/lib/jellyfin/)
    if [ -n "$differences" ]; then
      echo "Jellyfin state differs after import:" >&2
      echo "$differences" >&2
      exit 1
    fi
  '';
in
{
  imports = [
    ./base.nix
    ../modules/services/jellyfin.nix
    (import ./mkMicrovmConfig.nix (
      reg
      // {
        volumes = [
          {
            mountPoint = "/var/lib/jellyfin";
            image = "jellyfin-state.img";
            size = 131072;
          }
          {
            mountPoint = "/var/cache/jellyfin";
            image = "jellyfin-cache.img";
            size = 131072;
          }
        ];
        extraShares = [
          {
            source = libraryPath;
            mountPoint = libraryPath;
            tag = "jellyfin-media";
            proto = "virtiofs";
            readOnly = true;
          }
        ]
        ++ lib.optionals (!jellyfinSettings.vmServiceReady) [
          {
            source = "/var/lib/jellyfin";
            mountPoint = "/mnt/host-jellyfin";
            tag = "jellyfin-host-state";
            proto = "virtiofs";
            readOnly = true;
          }
        ];
      }
    ))
  ];

  assertions = [
    {
      assertion = !gpu.enable || gpu.pciFunctions != [ ];
      message = "jellyfin-vm: GPU passthrough needs the card's PCI functions";
    }
    {
      assertion =
        !gpu.enable
        || lib.all (
          path: builtins.match "[0-9a-fA-F]{4}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\\.[0-7]" path != null
        ) gpu.pciFunctions;
      message = "jellyfin-vm: GPU PCI functions must use domain:bus:slot.function addresses";
    }
  ];

  microvm.devices = lib.optionals gpu.enable (
    map (path: {
      bus = "pci";
      inherit path;
    }) gpu.pciFunctions
  );

  # Declare the user before the service is enabled so staged state can be
  # copied into its final volume with the correct guest ownership.
  users.users.jellyfin = {
    isSystemUser = true;
    group = "jellyfin";
  };
  users.groups.jellyfin = { };
  environment.systemPackages = lib.optionals (!jellyfinSettings.vmServiceReady) [ migrationScript ];

  # The base VM admin has SSH-key login but no password for ordinary sudo.
  # Expose one fixed import command only during the stopped-service stage.
  security.sudo.extraRules = lib.optionals (!jellyfinSettings.vmServiceReady) [
    {
      users = [ "admin" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/jellyfin-import-state";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  sys.services.jellyfin = {
    enable = jellyfinSettings.vmServiceReady;
    openFirewall = false;
  };
  services.jellyfin.hardwareAcceleration.enable = false;

  # The host-owned TCP relay is the only HTTP peer. Other MicroVMs have no
  # declared lateral permission to reach Jellyfin, and the guest adds its own
  # source restriction as a second boundary.
  networking.firewall.extraCommands = ''
    iptables -w -I INPUT 1 -i microvm0 -s 10.100.0.1/32 -p tcp --dport ${toString reg.port} -j ACCEPT
  '';
}
