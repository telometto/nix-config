{
  pkgs,
  snowfall,
  blizzard,
  consts,
}:
let
  inherit (pkgs) lib;
  hosts = [
    snowfall
    blizzard
  ];
  customPort = 22022;
  validHost = host: builtins.tryEval host.config.system.build.toplevel.drvPath;
  # Negative fixtures need only this module, not another complete desktop
  # evaluation for every assertion. The positive contract covers both hosts.
  targetFixture =
    module:
    import (pkgs.path + "/nixos/lib/eval-config.nix") {
      system = pkgs.stdenv.hostPlatform.system;
      specialArgs = { inherit consts; };
      modules = [
        ../modules/security/sandfly-target.nix
        {
          system.stateVersion = "26.05";
          boot.loader.grub.enable = false;
          fileSystems."/" = {
            device = "none";
            fsType = "tmpfs";
          };
          services.tailscale.enable = true;
          services.openssh.enable = true;
          sys.security.sandflyTarget = {
            enable = true;
            tailscalePolicyReady = true;
            listenAddress = consts.tailscale.hosts.snowfall.ipv4;
            authorizedKeys = snowfall.config.sys.security.sandflyTarget.authorizedKeys;
          };
        }
        module
      ];
    };
  failed =
    message: host: lib.any (item: !item.assertion && item.message == message) host.config.assertions;
  missingPolicy = targetFixture (
    { lib, ... }: {
      sys.security.sandflyTarget.tailscalePolicyReady = lib.mkForce false;
    }
  );
  missingKeys = targetFixture (
    { lib, ... }: {
      sys.security.sandflyTarget.authorizedKeys = lib.mkForce [ ];
    }
  );
  disabledTailscale = targetFixture (
    { lib, ... }: {
      services.tailscale.enable = lib.mkForce false;
    }
  );
  disabledFirewall = targetFixture (
    { lib, ... }: {
      networking.firewall.enable = lib.mkForce false;
    }
  );
  wrongBackend = targetFixture (
    { lib, ... }: {
      networking.firewall.backend = lib.mkForce "nftables";
    }
  );
  sharedPort = targetFixture (
    { lib, ... }: {
      sys.security.sandflyTarget.port = lib.mkForce 22;
    }
  );
  ordinaryKeys = targetFixture {
    users.users.sandfly.openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAA test-only" ];
  };
  disabledTarget = targetFixture (
    { lib, ... }: {
      sys.security.sandflyTarget.enable = lib.mkForce false;
    }
  );
  # Exercise the supported rotation overlap and a nondefault listener port
  # through the actual module renderer, without another full host evaluation.
  overlapTarget = targetFixture (
    { lib, ... }: {
      sys.security.sandflyTarget = {
        port = lib.mkForce customPort;
        authorizedKeys = lib.mkForce (
          snowfall.config.sys.security.sandflyTarget.authorizedKeys
          ++ [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGoJQoGpAoRuSbAoQTdCbGRc3xJQ77aCpHwoXTjpSiHp test-rotation"
          ]
        );
      };
    }
  );
  hostContract =
    host:
    let
      cfg = host.config;
      target = cfg.sys.security.sandflyTarget;
      expectedAddress = consts.tailscale.hosts.${cfg.networking.hostName}.ipv4;
    in
    assert (validHost host).success;
    assert target.listenAddress == expectedAddress;
    assert target.scannerAddress == consts.tailscale.hosts.sandfly.ipv4;
    assert target.port == consts.ports.host.sandflySsh;
    assert
      cfg.systemd.sockets.sandfly-sshd.listenStreams == [
        "${expectedAddress}:${toString target.port}"
      ];
    assert cfg.systemd.sockets.sandfly-sshd.socketConfig.FreeBind;
    assert cfg.systemd.sockets.sandfly-sshd.socketConfig.Accept;
    assert lib.elem "firewall.service" cfg.systemd.sockets.sandfly-sshd.partOf;
    assert lib.elem "sandfly" cfg.services.openssh.settings.DenyUsers;
    assert lib.elem "--ssh" cfg.services.tailscale.extraSetFlags;
    assert !(lib.elem target.port cfg.networking.firewall.allowedTCPPorts);
    assert lib.elem target.port cfg.networking.firewall.interfaces.tailscale0.allowedTCPPorts;
    assert cfg.users.users.sandfly.hashedPassword == "!";
    assert cfg.users.users.sandfly.homeMode == "0700";
    assert cfg.users.users.sandfly.extraGroups == [ ];
    assert cfg.users.users.sandfly.openssh.authorizedKeys.keys == [ ];
    assert cfg.users.users.sandfly.openssh.authorizedKeys.keyFiles == [ ];
    assert lib.any (
      rule:
      lib.elem "sandfly" rule.users
      && lib.any (
        command: builtins.isAttrs command && command.command == "ALL" && lib.elem "NOPASSWD" command.options
      ) rule.commands
    ) cfg.security.sudo.extraRules;
    assert cfg.environment.etc."ssh/sandfly-authorized_keys".mode == "0444";
    assert lib.hasInfix "/usr/local/bin/sudo" cfg.system.activationScripts.sandflySudoCompat.text;
    true;
  firewall =
    port: address:
    import ../lib/sandfly-firewall.nix {
      listenAddress = consts.tailscale.hosts.snowfall.ipv4;
      scannerAddress = address;
      inherit port;
    };
  current = firewall consts.ports.host.sandflySsh consts.tailscale.hosts.sandfly.ipv4;
  next = firewall consts.ports.host.sandflySsh "100.99.88.77";
  custom = firewall overlapTarget.config.sys.security.sandflyTarget.port consts.tailscale.hosts.sandfly.ipv4;
  customNext = firewall overlapTarget.config.sys.security.sandflyTarget.port "100.99.88.77";
  script = name: contents: pkgs.writeText name contents;
  checkSsh =
    host:
    let
      cfg = host.config;
    in
    ''
      sshd -G -T -f ${cfg.environment.etc."ssh/sandfly_sshd_config".source} > effective.json-lines
      python3 ${./sandfly-ssh-test.py} \
        effective.json-lines \
        ${cfg.environment.etc."ssh/sandfly-authorized_keys".source} \
        ${cfg.sys.security.sandflyTarget.listenAddress} \
        ${cfg.sys.security.sandflyTarget.scannerAddress} \
        ${toString cfg.sys.security.sandflyTarget.port} \
        ${script "sandfly-declared-keys.json" (
          builtins.toJSON cfg.sys.security.sandflyTarget.authorizedKeys
        )}
      ssh-keygen -lf ${cfg.environment.etc."ssh/sandfly-authorized_keys".source}
    '';
in
assert lib.all hostContract hosts;
assert (validHost overlapTarget).success;
assert overlapTarget.config.sys.security.sandflyTarget.port == customPort;
assert
  overlapTarget.config.systemd.sockets.sandfly-sshd.listenStreams == [
    "${overlapTarget.config.sys.security.sandflyTarget.listenAddress}:${toString customPort}"
  ];
assert lib.elem customPort
  overlapTarget.config.networking.firewall.interfaces.tailscale0.allowedTCPPorts;
assert
  snowfall.config.sys.security.sandflyTarget.authorizedKeys
  != blizzard.config.sys.security.sandflyTarget.authorizedKeys;
assert failed
  "Review docs/sandfly.md and confirm human Tailscale SSH denies sandfly and root before setting sys.security.sandflyTarget.tailscalePolicyReady."
  missingPolicy;
assert failed "sys.security.sandflyTarget requires at least one dedicated scanner public key."
  missingKeys;
assert failed "sys.security.sandflyTarget requires the effective services.tailscale.enable option."
  disabledTailscale;
assert failed
  "sys.security.sandflyTarget requires the enabled iptables firewall for its early source guard."
  disabledFirewall;
assert failed
  "sys.security.sandflyTarget requires the enabled iptables firewall for its early source guard."
  wrongBackend;
assert failed
  "sys.security.sandflyTarget.port must be separate from human SSH and ordinary OpenSSH ports."
  sharedPort;
assert failed
  "Install scanner keys only through sys.security.sandflyTarget.authorizedKeys, never ordinary OpenSSH authorized keys."
  ordinaryKeys;
assert !(builtins.hasAttr "sandfly" disabledTarget.config.users.users);
assert !(builtins.hasAttr "sandfly-sshd" disabledTarget.config.systemd.sockets);
assert !(builtins.hasAttr "ssh/sandfly-authorized_keys" disabledTarget.config.environment.etc);
pkgs.runCommand "sandfly-target-tests"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.bash
      pkgs.openssh
    ];
  }
  ''
    ${lib.concatMapStrings checkSsh (hosts ++ [ overlapTarget ])}
    python3 ${./sandfly-ssh-validator-test.py} ${./sandfly-ssh-test.py}
    python3 ${./sandfly-firewall-test.py} \
      ${script "sandfly-current-start" current.extraCommands} \
      ${script "sandfly-current-stop" current.extraStopCommands} \
      ${script "sandfly-next-start" next.extraCommands} \
      ${toString consts.ports.host.sandflySsh}
    python3 ${./sandfly-firewall-test.py} \
      ${script "sandfly-custom-start" custom.extraCommands} \
      ${script "sandfly-custom-stop" custom.extraStopCommands} \
      ${script "sandfly-custom-next-start" customNext.extraCommands} \
      ${toString overlapTarget.config.sys.security.sandflyTarget.port}
    touch "$out"
  ''
