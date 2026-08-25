{
  config,
  lib,
  pkgs,
  consts,
  ...
}:
let
  immichReg = (import ../../../vms/vm-registry.nix { inherit consts; }).immich;
  immichStorage = import ../../../vms/immich-storage.nix;
  immichBackupVolumes = immichStorage.backupVolumes;
  immichVmName = "${immichReg.name}-vm";
  immichVmUnit = "microvm@${immichVmName}.service";
  immichVmEnabled = config.sys.virtualisation.microvm.instances.${immichReg.name}.enable or false;
  microvmStateDir = config.sys.virtualisation.microvm.stateDir;
  microvmStateDataset = lib.removePrefix "/" microvmStateDir;
  immichSnapshot = "${immichReg.name}-rsyncnet";
  immichSnapshotRef = "${microvmStateDataset}@${immichSnapshot}";
  immichSnapshotPath = "${microvmStateDir}/.zfs/snapshot/${immichSnapshot}/${immichVmName}";
  immichBackupPaths = map (volume: "${immichSnapshotPath}/${volume.image}") immichBackupVolumes;
  immichBackupNames = map (volume: volume.name) immichBackupVolumes;
  immichBackupImages = map (volume: volume.image) immichBackupVolumes;
  pushoverEnabled = config.sys.services.grafanaPushover.enable or false;

  rsyncNetKey = "/root/.ssh/immich-rsyncnet";
  rsyncNetKnownHosts = "/root/.ssh/known_hosts-rsyncnet";

  curl = lib.getExe pkgs.curl;
  systemctl = lib.getExe' pkgs.systemd "systemctl";
  zfs = lib.getExe' pkgs.zfs "zfs";
  stat = lib.getExe' pkgs.coreutils "stat";
in
lib.mkIf immichVmEnabled {
  assertions = [
    {
      assertion = lib.hasPrefix "/" microvmStateDir;
      message = "Immich backup requires sys.virtualisation.microvm.stateDir to be an absolute ZFS dataset mount path";
    }
    {
      assertion =
        immichBackupVolumes != [ ]
        && builtins.length (lib.unique immichBackupNames) == builtins.length immichBackupNames
        && builtins.length (lib.unique immichBackupImages) == builtins.length immichBackupImages;
      message = "vms/immich-storage.nix must define unique backup volume names and image files";
    }
    {
      assertion = lib.any (volume: volume.mountPoint == "/persist") immichBackupVolumes;
      message = "Immich backup storage contract must include the /persist volume";
    }
  ];

  services.borgbackup.jobs.immich-rsyncnet = {
    repo = "ssh://zh6100@zh6100.rsync.net/./immich-borg";
    paths = immichBackupPaths;

    startAt = "03:30";
    persistentTimer = true;
    doInit = false;
    compression = "zstd,3";
    archiveBaseName = "blizzard-immich";
    wrapper = null;

    environment.BORG_RSH = "ssh -i ${rsyncNetKey} -o BatchMode=yes -o ConnectTimeout=30 -o IdentitiesOnly=yes -o ServerAliveInterval=10 -o ServerAliveCountMax=30 -o StrictHostKeyChecking=yes -o UserKnownHostsFile=${rsyncNetKnownHosts}";
    encryption = {
      mode = "repokey-blake2";
      passCommand = "cat ${config.sys.secrets.borgKeyFile}";
    };

    extraArgs = [
      "--remote-path=borg14"
      "--lock-wait=600"
    ];
    extraCreateArgs = [ "--stats" ];

    preHook = ''
      immichVmRestoreNeeded=0
      immichSnapshotCreated=0

      for requiredFile in \
        ${lib.escapeShellArg rsyncNetKey} \
        ${lib.escapeShellArg rsyncNetKnownHosts} \
        ${lib.escapeShellArg config.sys.secrets.borgKeyFile}; do
        if [ ! -s "$requiredFile" ]; then
          echo "Required Immich backup credential file is missing or empty: $requiredFile" >&2
          exit 1
        fi
      done

      for rootOwnedFile in \
        ${lib.escapeShellArg rsyncNetKey} \
        ${lib.escapeShellArg rsyncNetKnownHosts}; do
        rootOwnedFileOwner="$(${stat} --format='%U' "$rootOwnedFile")"
        if [ "$rootOwnedFileOwner" != "root" ]; then
          echo "Refusing to use $rootOwnedFile: expected owner root, got $rootOwnedFileOwner" >&2
          exit 1
        fi
      done

      rsyncNetKeyMode="$(${stat} --format='%a' ${lib.escapeShellArg rsyncNetKey})"
      case "$rsyncNetKeyMode" in
        400|600) ;;
        *)
          echo "Refusing to use ${rsyncNetKey}: expected mode 0400 or 0600, got $rsyncNetKeyMode" >&2
          exit 1
          ;;
      esac

      rsyncNetKnownHostsMode="$(${stat} --format='%a' ${lib.escapeShellArg rsyncNetKnownHosts})"
      case "$rsyncNetKnownHostsMode" in
        400|600|644) ;;
        *)
          echo "Refusing to use ${rsyncNetKnownHosts}: expected mode 0400, 0600, or 0644, got $rsyncNetKnownHostsMode" >&2
          exit 1
          ;;
      esac

      microvmStateMountpoint="$(${zfs} get -H -o value mountpoint ${lib.escapeShellArg microvmStateDataset})"
      if [ "$microvmStateMountpoint" != ${lib.escapeShellArg microvmStateDir} ]; then
        echo "Refusing to snapshot ${microvmStateDataset}: its ZFS mountpoint is $microvmStateMountpoint, expected ${microvmStateDir}" >&2
        exit 1
      fi

      if ! borgWrapper list "''${extraArgs[@]}" >/dev/null; then
        echo "Immich backup repository preflight failed; leaving the VM untouched" >&2
        exit 1
      fi

      immichVmState="$(${systemctl} show --property=ActiveState --value ${lib.escapeShellArg immichVmUnit})"
      if [ "$immichVmState" != "active" ]; then
        echo "Refusing to back up Immich while ${immichVmUnit} is $immichVmState" >&2
        exit 1
      fi

      immichVmRestoreNeeded=1
      ${systemctl} stop ${lib.escapeShellArg immichVmUnit}

      if ${zfs} list -H -t snapshot -o name ${lib.escapeShellArg immichSnapshotRef} >/dev/null 2>&1; then
        ${zfs} destroy ${lib.escapeShellArg immichSnapshotRef}
      fi

      ${zfs} snapshot ${lib.escapeShellArg immichSnapshotRef}
      immichSnapshotCreated=1

      for backupPath in ${lib.escapeShellArgs immichBackupPaths}; do
        if [ ! -f "$backupPath" ]; then
          echo "Immich backup image is missing from the ZFS snapshot: $backupPath" >&2
          exit 1
        fi
      done

      ${systemctl} start ${lib.escapeShellArg immichVmUnit}
      if ! ${systemctl} is-active --quiet ${lib.escapeShellArg immichVmUnit}; then
        echo "Immich VM did not return to the active state after snapshot creation" >&2
        exit 1
      fi
      immichVmRestoreNeeded=0
    '';

    postHook = ''
      cleanupFailed=0

      if [ "''${immichVmRestoreNeeded:-0}" -eq 1 ]; then
        echo "Restoring ${immichVmUnit} after an interrupted backup setup" >&2
        if ${systemctl} start ${lib.escapeShellArg immichVmUnit} \
          && ${systemctl} is-active --quiet ${lib.escapeShellArg immichVmUnit}; then
          immichVmRestoreNeeded=0
        else
          echo "Failed to restore ${immichVmUnit}; manual intervention is required" >&2
          cleanupFailed=1
        fi
      fi

      if [ "''${immichSnapshotCreated:-0}" -eq 1 ]; then
        if ${zfs} destroy ${lib.escapeShellArg immichSnapshotRef}; then
          immichSnapshotCreated=0
        else
          echo "Failed to destroy ZFS snapshot ${immichSnapshotRef}; manual cleanup is required" >&2
          cleanupFailed=1
        fi
      fi

      if [ "$cleanupFailed" -ne 0 ]; then
        exit 1
      fi
    '';
  };

  # A persistent timer can fire during boot. Waiting for multi-user.target and
  # ordering after the VM prevents the backup from racing MicroVM autostart.
  # The backup does not want/require the VM, so an intentionally stopped VM
  # remains stopped and the job fails closed.
  systemd.services."borgbackup-job-immich-rsyncnet" = {
    wants = [ "network-online.target" ];
    after = [
      "network-online.target"
      "multi-user.target"
      immichVmUnit
    ];
    unitConfig = lib.optionalAttrs pushoverEnabled {
      OnFailure = [ "immich-backup-failure-notify.service" ];
    };
    serviceConfig = {
      ProtectHome = "read-only";
      ReadOnlyPaths = [
        "-${rsyncNetKey}"
        "-${rsyncNetKnownHosts}"
      ];
    };
  };

  systemd.services.immich-backup-failure-notify = lib.mkIf pushoverEnabled {
    description = "Notify Pushover when the Immich backup fails";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    script = ''
      ${curl} \
        --fail \
        --silent \
        --show-error \
        --max-time 30 \
        --retry 2 \
        --form "token=<${config.sys.secrets.pushoverApiTokenFile}" \
        --form "user=<${config.sys.secrets.pushoverUserKeyFile}" \
        --form-string "title=Immich backup failed" \
        --form-string "message=borgbackup-job-immich-rsyncnet.service failed on blizzard. Inspect its journal before the next scheduled run." \
        https://api.pushover.net/1/messages.json
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      ReadOnlyPaths = [
        config.sys.secrets.pushoverApiTokenFile
        config.sys.secrets.pushoverUserKeyFile
      ];
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
      ];
      UMask = "0077";
    };
  };
}
