{
  pkgs,
  snowfall,
}:
let
  inherit (pkgs) lib;

  validTarget = snowfall.extendModules {
    modules = [
      {
        sys.security.sandflyTarget = {
          enable = true;
          tailscalePolicyReady = true;
        };
      }
    ];
  };

  validCfg = validTarget.config;
  validEvaluation = builtins.tryEval validCfg.system.build.toplevel.drvPath;

  hasFailedAssertion = message: cfg:
    lib.any (assertion: !assertion.assertion && assertion.message == message) cfg.assertions;

  missingPolicyConfirmation = snowfall.extendModules {
    modules = [
      (
        { lib, ... }:
        {
          sys.security.sandflyTarget = {
            enable = true;
            tailscalePolicyReady = lib.mkForce false;
          };
        }
      )
    ];
  };

  disabledEffectiveTailscale = snowfall.extendModules {
    modules = [
      (
        { lib, ... }:
        {
          sys.security.sandflyTarget = {
            enable = true;
            tailscalePolicyReady = true;
          };
          sys.services.tailscale.settings.enable = lib.mkForce false;
        }
      )
    ];
  };

  disabledTarget = snowfall.extendModules {
    modules = [
      (
        { lib, ... }:
        {
          sys.security.sandflyTarget.enable = lib.mkForce false;
        }
      )
    ];
  };

  hasSandflySudoRule = lib.any (
    rule:
    lib.elem "sandfly" rule.users
    && lib.any (
      command: builtins.isAttrs command && command.command == "ALL" && lib.elem "NOPASSWD" command.options
    ) rule.commands
  ) validCfg.security.sudo.extraRules;
in
assert validEvaluation.success;
assert hasFailedAssertion
  "Review docs/sandfly.md and set sys.security.sandflyTarget.tailscalePolicyReady only after restricting the tailnet SSH policy."
  missingPolicyConfirmation.config;
assert hasFailedAssertion
  "sys.security.sandflyTarget requires the effective services.tailscale.enable option."
  disabledEffectiveTailscale.config;
assert lib.elem "--ssh" validCfg.services.tailscale.extraSetFlags;
assert validCfg.users.users.sandfly.hashedPassword == "!";
assert hasSandflySudoRule;
assert lib.hasInfix "/usr/local/bin/sudo" validCfg.system.activationScripts.sandflySudoCompat.text;
assert !(builtins.hasAttr "sandfly" disabledTarget.config.users.users);
pkgs.runCommand "sandfly-target-tests" { } "touch $out"
