{
  config,
  lib,
  pkgs,
  ...
}:
let
  webzfsHost = "100.86.227.97";
  webzfsPort = 26619;
  wrapperPackageDir = builtins.dirOf config.security.wrapperDir;
  zfsPackage = config.boot.zfs.package or pkgs.zfs;

  sudoCommands = [
    "${zfsPackage}/bin/zfs"
    "${zfsPackage}/bin/zpool"
    "${zfsPackage}/bin/zdb"
    "${pkgs.smartmontools}/bin/smartctl"
    "${pkgs.util-linux}/bin/lsblk"
    "${pkgs.util-linux}/bin/blkid"
    "${pkgs.util-linux}/bin/blockdev"
    "${pkgs.sanoid}/bin/sanoid"
    "${pkgs.sanoid}/bin/syncoid"
    "${pkgs.systemd}/bin/systemctl"
  ];
in
{
  sops.secrets."webzfs/secret_key" = {
    owner = "webzfs";
    group = "webzfs";
    mode = "0440";
  };

  users.groups.webzfs = { };

  users.users.webzfs = {
    isSystemUser = true;
    group = "webzfs";
    home = "/var/lib/webzfs";
    createHome = true;
    extraGroups = [
      "shadow"
      "systemd-journal"
    ];
  };

  services.webzfs = {
    enable = true;

    package = pkgs.webzfs;
    host = webzfsHost;
    port = webzfsPort;
    openFirewall = false;
    user = "webzfs";
    group = "webzfs";
    dataDir = "/var/lib/webzfs";
    secretKeyFile = config.sops.secrets."webzfs/secret_key".path;

    settings = {
      CAPTION = "WebZFS";
      AUTH_SESSION_EXPIRES_SECONDS = 3600;
    };

    path = with pkgs; [
      zfsPackage
      coreutils
      diffutils
      gnugrep
      gnutar
      gzip
      iproute2
      kmod
      procps
      sanoid
      smartmontools
      systemd
      util-linux
      which
    ];
  };

  security.sudo.extraRules = [
    {
      users = [ "webzfs" ];
      commands = map (command: {
        inherit command;
        options = [ "NOPASSWD" ];
      }) sudoCommands;
    }
  ];

  systemd.services.webzfs = {
    path = lib.mkBefore [ wrapperPackageDir ];

    after = [
      "network-online.target"
      "tailscaled.service"
    ];
    wants = [
      "network-online.target"
      "tailscaled.service"
    ];
  };
}
