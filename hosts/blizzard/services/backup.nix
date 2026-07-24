{
  config,
  lib,
  pkgs,
  VARS,
  ...
}:
let
  borgKnownHostsFile = "/home/${VARS.users.zeno.user}/.ssh/known_hosts-borg-blizzard";
  immichBackupRoot = "/run/immich-backup";
  immichSnapshot = "immich-rsyncnet";
  immichSnapshotPath = "/flash/enc/vms/.zfs/snapshot/${immichSnapshot}/immich-vm";
  rsyncNetKey = "/home/${VARS.users.zeno.user}/.ssh/rsyncnet";
  rsyncNetKnownHosts = "/home/${VARS.users.zeno.user}/.ssh/known_hosts";

  systemctl = lib.getExe' pkgs.systemd "systemctl";
  zfs = lib.getExe' pkgs.zfs "zfs";
  mount = lib.getExe' pkgs.util-linux "mount";
  umount = lib.getExe' pkgs.util-linux "umount";
  mkdir = lib.getExe' pkgs.coreutils "mkdir";
in
{
  # Retain the dormant legacy homeserver job without enabling it. Immich uses
  # its own rsync.net repository below so enabling this wrapper cannot
  # accidentally start the old BorgBase job.
  sys.services.borgbackup = {
    enable = false;

    jobs.homeserver = {
      paths = [ "/home/${VARS.users.zeno.user}" ];
      environment.BORG_RSH = "ssh -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=${borgKnownHostsFile} -i /home/${VARS.users.zeno.user}/.ssh/borg-blizzard";
      repo = config.sys.secrets.borgRepo or "ssh://iu445agy@iu445agy.repo.borgbase.com/./repo";
      compression = "zstd,8";
      startAt = "daily";

      encryption = {
        mode = "repokey-blake2";
        passCommand = "cat ${config.sys.secrets.borgKeyFile}";
      };
    };
  };

  systemd.tmpfiles.rules = [ "d ${immichBackupRoot} 0700 root root -" ];

  services.borgbackup.jobs.immich-rsyncnet = {
    repo = "ssh://zh6100@zh6100.rsync.net/./immich-borg";
    paths = [
      "${immichBackupRoot}/immich"
      "${immichBackupRoot}/postgresql"
      "${immichBackupRoot}/persist"
    ];

    startAt = "03:30";
    persistentTimer = true;
    doInit = true;
    compression = "zstd,3";
    archiveBaseName = "blizzard-immich";

    environment.BORG_RSH = "ssh -i ${rsyncNetKey} -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=${rsyncNetKnownHosts}";
    encryption = {
      mode = "repokey-blake2";
      passCommand = "cat ${config.sys.secrets.borgKeyFile}";
    };

    extraArgs = [ "--remote-path=borg14" ];
    extraCreateArgs = [ "--stats" ];
    prune.keep = {
      daily = 7;
      weekly = 4;
      monthly = 6;
    };

    readWritePaths = [ immichBackupRoot ];

    preHook = ''
      if ${systemctl} is-active --quiet microvm@immich-vm.service; then
        ${systemctl} stop microvm@immich-vm.service
      else
        echo "Refusing to back up Immich while its VM is unexpectedly inactive" >&2
        exit 1
      fi

      ${zfs} destroy flash/enc/vms@${immichSnapshot} 2>/dev/null || true
      ${zfs} snapshot flash/enc/vms@${immichSnapshot}
      ${systemctl} start microvm@immich-vm.service

      ${mkdir} -p \
        ${immichBackupRoot}/immich \
        ${immichBackupRoot}/postgresql \
        ${immichBackupRoot}/persist

      ${mount} -o ro,noload,loop \
        ${immichSnapshotPath}/immich-state.img \
        ${immichBackupRoot}/immich
      ${mount} -o ro,noload,loop \
        ${immichSnapshotPath}/postgresql-state.img \
        ${immichBackupRoot}/postgresql
      ${mount} -o ro,noload,loop \
        ${immichSnapshotPath}/persist.img \
        ${immichBackupRoot}/persist
    '';

    postHook = ''
      ${umount} ${immichBackupRoot}/persist 2>/dev/null || true
      ${umount} ${immichBackupRoot}/postgresql 2>/dev/null || true
      ${umount} ${immichBackupRoot}/immich 2>/dev/null || true

      if ! ${systemctl} is-active --quiet microvm@immich-vm.service; then
        ${systemctl} start microvm@immich-vm.service || true
      fi

      ${zfs} destroy flash/enc/vms@${immichSnapshot} 2>/dev/null || true
    '';
  };
}
