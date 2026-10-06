{
  config,
  lib,
  pkgs,
  consts,
  ...
}:
let
  cfg = config.sys.security.sandflyTarget;
  sudoPath = "/usr/local/bin/sudo";
  wrappedSudo = "${config.security.wrapperDir}/sudo";
  stateDir = "/var/lib/sandfly-target";
  ownershipMarker = "${stateDir}/sudo-link-owned";
  sshPackage = config.services.openssh.package;
  authorizedKeysPath = "/etc/ssh/sandfly-authorized_keys";
  sshConfig = pkgs.writeText "sandfly-sshd_config" ''
    AddressFamily inet
    Port ${toString cfg.port}
    ListenAddress ${cfg.listenAddress}
    HostKey /etc/ssh/ssh_host_ed25519_key
    AllowUsers sandfly@${cfg.scannerAddress}
    AuthenticationMethods publickey
    PubkeyAuthentication yes
    AuthorizedKeysFile ${authorizedKeysPath}
    AuthorizedKeysCommand none
    TrustedUserCAKeys none
    PasswordAuthentication no
    KbdInteractiveAuthentication no
    PermitRootLogin no
    UsePAM yes
    StrictModes yes
    DisableForwarding yes
    PermitTunnel no
    PermitUserRC no
    PermitUserEnvironment no
    UseDNS no
    LogLevel VERBOSE
    Subsystem sftp internal-sftp
  '';
  firewall = import ../../lib/sandfly-firewall.nix {
    inherit (cfg) listenAddress scannerAddress port;
  };
  ipv4Octet = "([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])";
  tailscaleIPv4 = lib.types.strMatching "100\\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\\.${ipv4Octet}\\.${ipv4Octet}";
in
{
  options.sys.security.sandflyTarget = {
    enable = lib.mkEnableOption "the local account used when this host is scanned by Sandfly";

    tailscalePolicyReady = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Confirms that human Tailscale SSH allows only zeno with reauthentication
        and denies sandfly and root, including through broader additive rules.
        The scanner uses dedicated OpenSSH instead. Nix cannot verify the live
        policy; review docs/sandfly.md before setting this to true.
      '';
    };

    listenAddress = lib.mkOption {
      type = tailscaleIPv4;
      description = "This target's verified Tailscale IPv4, sourced from consts.tailscale.hosts.";
    };

    scannerAddress = lib.mkOption {
      type = tailscaleIPv4;
      default = consts.tailscale.hosts.sandfly.ipv4;
      description = "The only Tailscale IPv4 allowed to connect to the scan listener.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = consts.ports.host.sandflySsh;
      description = "Dedicated scan listener port; human Tailscale SSH stays on TCP 22.";
    };

    authorizedKeys = lib.mkOption {
      type = lib.types.listOf (lib.types.strMatching "ssh-ed25519 [A-Za-z0-9+/]+={0,2}( [^\n]*)?");
      default = [ ];
      description = "Dedicated scanner public keys for this host. Never supply private keys.";
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
          message = "Review docs/sandfly.md and confirm human Tailscale SSH denies sandfly and root before setting sys.security.sandflyTarget.tailscalePolicyReady.";
        }
        {
          assertion = config.services.openssh.enable && config.services.openssh.settings.UsePAM;
          message = "sys.security.sandflyTarget requires OpenSSH with PAM for its locked-password account, privilege separation user, and host keys.";
        }
        {
          assertion = config.networking.firewall.enable && config.networking.firewall.backend == "iptables";
          message = "sys.security.sandflyTarget requires the enabled iptables firewall for its early source guard.";
        }
        {
          assertion = cfg.port != 22 && !(lib.elem cfg.port config.services.openssh.ports);
          message = "sys.security.sandflyTarget.port must be separate from human SSH and ordinary OpenSSH ports.";
        }
        {
          assertion = cfg.authorizedKeys != [ ];
          message = "sys.security.sandflyTarget requires at least one dedicated scanner public key.";
        }
        {
          assertion = lib.any (
            key: key.type == "ed25519" && key.path == "/etc/ssh/ssh_host_ed25519_key"
          ) config.services.openssh.hostKeys;
          message = "sys.security.sandflyTarget requires the standard Ed25519 OpenSSH host key.";
        }
        {
          assertion =
            config.users.users.sandfly.openssh.authorizedKeys.keys == [ ]
            && config.users.users.sandfly.openssh.authorizedKeys.keyFiles == [ ];
          message = "Install scanner keys only through sys.security.sandflyTarget.authorizedKeys, never ordinary OpenSSH authorized keys.";
        }
      ];

      # Reconcile SSH mode on every activation of the Tailscale service.
      # extraUpFlags alone only affects initial login/re-authentication.
      services.tailscale.extraSetFlags = lib.mkAfter [ "--ssh" ];

      # Tailscale SSH has its own authentication; DenyUsers protects only
      # ordinary OpenSSH. The external human policy must also deny sandfly.
      services.openssh.settings.DenyUsers = [ "sandfly" ];

      environment.etc."ssh/sandfly-authorized_keys" = {
        mode = "0444";
        text = lib.concatMapStrings (key: ''
          from="${cfg.scannerAddress}",no-agent-forwarding,no-port-forwarding,no-X11-forwarding,no-user-rc ${key}
        '') cfg.authorizedKeys;
      };
      environment.etc."ssh/sandfly_sshd_config".source = sshConfig;

      # Match nixpkgs' ordinary OpenSSH validation: -G parses without needing
      # live private host keys or accounts in the build sandbox.
      system.checks = [
        (pkgs.runCommand "check-sandfly-sshd-config" { nativeBuildInputs = [ sshPackage ]; } ''
          sshd -G -T -f ${sshConfig} > /dev/null
          touch "$out"
        '')
      ];

      networking.firewall = {
        interfaces.tailscale0.allowedTCPPorts = [ cfg.port ];
        inherit (firewall) extraCommands extraStopCommands;
      };

      # An IP-bound socket survives tailscaled restarts. FreeBind lets it wait
      # for this exact address at boot without ever falling back to a wildcard.
      systemd.sockets.sandfly-sshd = {
        description = "Sandfly SSH on the target Tailscale IPv4";
        wantedBy = [ "sockets.target" ];
        after = [ "firewall.service" ];
        requires = [ "firewall.service" ];
        partOf = [ "firewall.service" ];
        listenStreams = [ "${cfg.listenAddress}:${toString cfg.port}" ];
        socketConfig = {
          Accept = true;
          FreeBind = true;
          MaxConnections = 16;
        };
      };

      systemd.services."sandfly-sshd@" = {
        description = "Sandfly SSH per-connection daemon";
        after = [ "sshd-keygen.service" ];
        requires = [ "sshd-keygen.service" ];
        path = [ sshPackage ];
        environment.LD_LIBRARY_PATH = config.system.nssModules.path;
        serviceConfig = {
          ExecStart = "${lib.getExe' sshPackage "sshd"} -i -e -f ${sshConfig}";
          StandardInput = "socket";
          StandardOutput = "socket";
          StandardError = "journal";
        };
      };

      users.users.sandfly = {
        isNormalUser = true;
        description = "Sandfly Security scanner";
        home = "/home/sandfly";
        createHome = true;
        homeMode = "0700";
        shell = pkgs.bashInteractive;
        hashedPassword = "!";

        # Dedicated listener authentication uses a root-managed key file.
        # Keep the home writable for Sandfly's temporary scanning binaries.
      };

      # Sandfly's forensic engine must inspect root-only areas. The reviewed
      # listener, key, source guard, and human Tailscale SSH policy protect
      # this root-equivalent account. Command allowlists for user-writable
      # uploaded binaries would not meaningfully restrict root execution.
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
