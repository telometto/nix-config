# Characterize the three existing consumers with synthetic metadata. The HM
# module value stays opaque here; its real integration is covered by
# package-scopes, while this fixture checks which profiles are generated.
{ pkgs }:
let
  inherit (pkgs) lib;
  fixture = {
    description = "Synthetic registry fixture";
    isNormalUser = true;
    hashedPassword = "$6$fixture$fixture";
    group = "users";
    extraGroups = [ "wheel" ];
    sshPubKey = "ssh-ed25519 Zml4dHVyZQ== registry-fixture";
  };
  alice = fixture // {
    user = "alice";
    uid = 1101;
  };
  bob = fixture // {
    user = "bob";
  };
  registry = {
    owner = alice;
    guest = bob;
    service = fixture // {
      user = "registry-daemon";
      isNormalUser = false;
    };
    inactive = fixture // {
      user = "inactive-user";
    };
  };
  make =
    {
      users ? registry,
      enabled ? [ ],
      overrides ? { },
      homes ? { },
    }:
    (import "${pkgs.path}/nixos/lib/eval-config.nix" {
      inherit pkgs;
      system = pkgs.stdenv.hostPlatform.system;
      specialArgs.VARS = { inherit users; };
      modules = [
        ../modules/core/user-options.nix
        ../modules/core/users.nix
        ../modules/core/home-options.nix
        ../modules/core/home-users.nix
        ../modules/core/roles.nix
        ../modules/desktop/base.nix
        {
          options.home-manager.users = lib.mkOption {
            type = lib.types.attrsOf lib.types.raw;
            default = { };
          };
          config = {
            system.stateVersion = "26.05";
            networking.hostName = "user-registry-fixture";
            sys = {
              users = lib.genAttrs enabled (_: {
                enable = true;
              });
              home = {
                enable = true;
                users = homes;
              };
            };
            users.users = overrides;
          };
        }
      ];
    }).config;
  failures =
    cfg:
    map (a: a.message) (
      lib.filter (
        a:
        !a.assertion
        && (
          lib.hasPrefix "VARS.users" a.message
          || lib.hasPrefix "Enabled users for user-registry-fixture" a.message
        )
      ) cfg.assertions
    );
  hasFailure = text: cfg: lib.any (lib.hasInfix text) (failures cfg);
  defaults = make { };
  enabled = make {
    enabled = [
      "alice"
      "bob"
      "registry-daemon"
    ];
    overrides.registry-daemon.isSystemUser = true;
  };
  optedOut = make {
    enabled = [
      "alice"
      "bob"
    ];
    homes.alice.enable = false;
  };
  duplicateNames = make {
    users = {
      first = alice;
      second = alice // {
        sshPubKey = "invalid-fixture-key";
      };
    };
    enabled = [ "alice" ];
  };
  duplicateUids = make {
    users = {
      first = alice;
      second = bob // {
        uid = 1101;
      };
    };
    enabled = [
      "alice"
      "bob"
    ];
  };
  disabledUidCollision = make {
    users = {
      first = alice;
      second = bob // {
        uid = 1101;
      };
    };
    enabled = [ "alice" ];
  };
  finalUidCollision = make {
    users = {
      first = alice;
      second = bob // {
        uid = 1102;
      };
    };
    enabled = [
      "alice"
      "bob"
    ];
    overrides.bob.uid = lib.mkForce 1101;
  };
  invalid = make {
    users = {
      missing = builtins.removeAttrs alice [ "user" ];
      empty = alice // {
        user = "";
      };
      nullName = alice // {
        user = null;
      };
      nonString = alice // {
        user = 42;
      };
    };
  };
  badDisabledUid = make {
    users.owner = alice // {
      uid = 0;
    };
  };
  extraKey = make {
    users.owner = alice // {
      gpgSshPubKey = "ssh-ed25519 Z3BnLWZpeHR1cmU= registry-gpg-fixture";
    };
    enabled = [ "alice" ];
  };
in
{
  optionsUseLogins =
    builtins.attrNames defaults.sys.users == [
      "alice"
      "bob"
      "inactive-user"
      "registry-daemon"
    ];
  accountsOptInPerHost = !(defaults.users.users ? alice) && !defaults.sys.users.alice.enable;
  enabledAccountsUseLogins = enabled.users.users ? alice && enabled.users.users ? bob;
  inactiveAccountExcluded = !(enabled.users.users ? inactive-user);
  optionalUidStaysNull = enabled.users.users.bob.uid == null;
  explicitUidPreserved = enabled.users.users.alice.uid == 1101;
  accountFieldsPreserved =
    enabled.users.users.alice.description == "Synthetic registry fixture"
    && enabled.users.users.alice.group == "users"
    && enabled.users.users.alice.extraGroups == [ "wheel" ]
    && enabled.users.users.alice.hashedPassword == "$6$fixture$fixture"
    && enabled.users.users.alice.shell == pkgs.zsh;
  authorizedKeyPreserved =
    enabled.users.users.alice.openssh.authorizedKeys.keys == [
      "ssh-ed25519 Zml4dHVyZQ== registry-fixture"
    ];
  optionalGpgKeyAppended =
    extraKey.users.users.alice.openssh.authorizedKeys.keys == [
      "ssh-ed25519 Zml4dHVyZQ== registry-fixture"
      "ssh-ed25519 Z3BnLWZpeHR1cmU= registry-gpg-fixture"
    ];
  homesOnlyForEnabledNormalUsers =
    builtins.attrNames enabled.home-manager.users == [
      "alice"
      "bob"
    ];
  homeOptOutPreserved = builtins.attrNames optedOut.home-manager.users == [ "bob" ];
  duplicateLoginStillRejected = hasFailure "duplicate login names: alice" duplicateNames;
  duplicateRecordStillValidated = hasFailure "VARS.users.second (alice) must define a valid bare OpenSSH" duplicateNames;
  duplicateAccountKeepsFirstPayload =
    duplicateNames.users.users.alice.openssh.authorizedKeys.keys == [
      "ssh-ed25519 Zml4dHVyZQ== registry-fixture"
    ];
  duplicateUidStillRejected = hasFailure "duplicate UIDs: 1101" duplicateUids;
  disabledUidCollisionIgnored = !(hasFailure "duplicate UIDs" disabledUidCollision);
  uidValidationUsesFinalAccount = hasFailure "duplicate UIDs: 1101" finalUidCollision;
  invalidLoginsKeepRoleOptions =
    builtins.attrNames invalid.sys.users == [
      "empty"
      "missing"
      "nonString"
      "nullName"
    ];
  everyInvalidRecordStillRejected =
    lib.all (role: hasFailure "VARS.users.${role}.user must be a non-empty string" invalid)
      [
        "empty"
        "missing"
        "nonString"
        "nullName"
      ];
  disabledRecordsStillValidated = hasFailure "may omit uid; when set, uid must be a positive integer" badDisabledUid;
}
