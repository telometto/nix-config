{ lib, config, ... }:
let
  cfg = config.sys.services.firefox;
in
{
  imports = [
    (import ../../lib/linuxserver-browser.nix {
      name = "firefox";
      title = "Firefox";
      image = (import ../../lib/oci-images.nix).firefox;
    })
  ];

  options.sys.services.firefox = {
    fileTransfer = {
      enable = lib.mkEnableOption "Firefox file transfers";

      hostPath = lib.mkOption {
        type = lib.types.str;
        default = "/home/admin/Downloads";
        description = "Writable VM path to expose to the browser file manager.";
      };

      containerPath = lib.mkOption {
        type = lib.types.str;
        default = "/downloads";
        description = "Path inside the Firefox container used for uploads and downloads.";
      };

      hostUid = lib.mkOption {
        type = lib.types.ints.positive;
        default = 1000;
        description = "Numeric owner UID for the VM-side file-transfer directory.";
      };

      sharedGid = lib.mkOption {
        type = lib.types.ints.positive;
        default = 1000;
        description = "Numeric group GID shared by the VM-side directory and container.";
      };

      containerUid = lib.mkOption {
        type = lib.types.ints.positive;
        default = 911;
        description = "PUID for the LinuxServer container's existing /config profile identity.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = lib.optional cfg.fileTransfer.enable "d ${cfg.fileTransfer.hostPath} 2770 ${toString cfg.fileTransfer.hostUid} ${toString cfg.fileTransfer.sharedGid} -";

    virtualisation.quadlet.containers.firefox.containerConfig = {
      environments = lib.optionalAttrs cfg.fileTransfer.enable {
        # The existing profile stays at its own UID; only the transfer group is shared.
        PUID = toString cfg.fileTransfer.containerUid;
        PGID = toString cfg.fileTransfer.sharedGid;
        FILE_MANAGER_PATH = cfg.fileTransfer.containerPath;
        SELKIES_FILE_TRANSFERS = "upload,download";
      };
      volumes = lib.mkAfter (
        lib.optional cfg.fileTransfer.enable "${cfg.fileTransfer.hostPath}:${cfg.fileTransfer.containerPath}"
      );
    };

    assertions = [
      {
        assertion = !cfg.fileTransfer.enable || lib.hasPrefix "/" cfg.fileTransfer.hostPath;
        message = "sys.services.firefox.fileTransfer.hostPath must be an absolute path";
      }
      {
        assertion = !cfg.fileTransfer.enable || lib.hasPrefix "/" cfg.fileTransfer.containerPath;
        message = "sys.services.firefox.fileTransfer.containerPath must be an absolute path";
      }
    ];
  };
}
