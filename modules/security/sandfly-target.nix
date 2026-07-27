{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.sys.security.sandflyTarget;
in
{
  options.sys.security.sandflyTarget.enable =
    lib.mkEnableOption "the local account used when this host is scanned by Sandfly";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.sys.services.tailscale.enable;
        message = "sys.security.sandflyTarget requires sys.services.tailscale.enable.";
      }
      {
        assertion = lib.elem "--ssh" config.sys.services.tailscale.extraUpFlags;
        message = "sys.security.sandflyTarget requires Tailscale SSH (--ssh).";
      }
    ];

    users.users.sandfly = {
      isNormalUser = true;
      description = "Sandfly Security scanner";
      home = "/home/sandfly";
      createHome = true;
      homeMode = "0700";
      shell = pkgs.bashInteractive;

      # Authentication is handled by Tailscale SSH. With no password or
      # authorized key configured, this account cannot use regular SSH
      # password/key authentication.
    };

    # Sandfly's forensic engine must inspect root-only areas. Its Tailscale SSH
    # policy is the boundary that restricts who can reach this privileged user.
    security.sudo.extraRules = [
      {
        users = [ "sandfly" ];
        commands = [
          {
            command = "ALL";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    # Sandfly expects sudo in a conventional FHS location. Point that path at
    # NixOS's privileged wrapper rather than the non-setuid store binary.
    systemd.tmpfiles.rules = [
      "d /usr/local/bin 0755 root root - -"
      "L+ /usr/local/bin/sudo - - - - ${config.security.wrapperDir}/sudo"
    ];
  };
}
