{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.sys.security.sandflyTarget;
  sudoPath = "/usr/local/bin/sudo";
  wrappedSudo = "${config.security.wrapperDir}/sudo";
  stateDir = "/var/lib/sandfly-target";
  ownershipMarker = "${stateDir}/sudo-link-owned";
in
{
  options.sys.security.sandflyTarget = {
    enable = lib.mkEnableOption "the local account used when this host is scanned by Sandfly";

    tailscalePolicyReady = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Confirms that the tailnet SSH policy restricts the literal sandfly
        login to dedicated scanner nodes and contains no broader rule that can
        select arbitrary non-root users on this host. This cannot be verified
        during Nix evaluation. See docs/sandfly.md before setting this to true.
      '';
    };
  };

  config = lib.mkMerge [
    {
      # This script owns only the compatibility link it created. On disable it
      # removes that link, but leaves an unrelated administrator-managed path
      # untouched. Ordering it before user activation avoids exposing the
      # Sandfly account before its required sudo path exists.
      system.activationScripts = {
        sandflySudoCompat = {
          deps = [ "wrappers" ];
          text =
            if cfg.enable then
              ''
                ${lib.getExe' pkgs.coreutils "install"} -d -m 0755 /usr/local/bin
                if [ -e ${sudoPath} ] || [ -L ${sudoPath} ]; then
                  existing_target="$(${lib.getExe' pkgs.coreutils "readlink"} ${sudoPath} || true)"
                  if [ "$existing_target" != ${lib.escapeShellArg wrappedSudo} ]; then
                    echo "${sudoPath} already exists and is not managed by sys.security.sandflyTarget" >&2
                    exit 1
                  fi
                else
                  ${lib.getExe' pkgs.coreutils "ln"} -s ${lib.escapeShellArg wrappedSudo} ${sudoPath}
                fi
                ${lib.getExe' pkgs.coreutils "install"} -d -m 0700 ${stateDir}
                ${lib.getExe' pkgs.coreutils "touch"} ${ownershipMarker}
              ''
            else
              ''
                if [ -e ${ownershipMarker} ] \
                  && [ -L ${sudoPath} ] \
                  && [ "$(${lib.getExe' pkgs.coreutils "readlink"} ${sudoPath})" = ${lib.escapeShellArg wrappedSudo} ]; then
                  ${lib.getExe' pkgs.coreutils "rm"} -f ${sudoPath}
                fi
                if [ -e ${ownershipMarker} ]; then
                  ${lib.getExe' pkgs.coreutils "rm"} -f ${ownershipMarker}
                  ${lib.getExe' pkgs.coreutils "rmdir"} --ignore-fail-on-non-empty ${stateDir}
                fi
              '';
        };
        users.deps = [ "sandflySudoCompat" ];
      };
    }

    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.services.tailscale.enable;
          message = "sys.security.sandflyTarget requires the effective services.tailscale.enable option.";
        }
        {
          assertion = cfg.tailscalePolicyReady;
          message = "Review docs/sandfly.md and set sys.security.sandflyTarget.tailscalePolicyReady only after restricting the tailnet SSH policy.";
        }
      ];

      # Reconcile SSH mode on every activation of the Tailscale service.
      # extraUpFlags alone only affects initial login/re-authentication.
      services.tailscale.extraSetFlags = lib.mkAfter [ "--ssh" ];

      users.users.sandfly = {
        isNormalUser = true;
        description = "Sandfly Security scanner";
        home = "/home/sandfly";
        createHome = true;
        homeMode = "0700";
        shell = pkgs.bashInteractive;
        hashedPassword = "!";

        # Authentication is handled by Tailscale SSH. No regular SSH
        # authorized keys are installed for this account.
      };

      # Sandfly's forensic engine must inspect root-only areas. The reviewed
      # Tailscale SSH policy is the boundary protecting this root-equivalent
      # account.
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
    })
  ];
}
