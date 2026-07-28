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

  missingPolicyConfirmation = snowfall.extendModules {
    modules = [
      {
        sys.security.sandflyTarget.enable = true;
      }
    ];
  };

  missingPolicyConfirmationEvaluation = builtins.tryEval missingPolicyConfirmation.config.system.build.toplevel.drvPath;

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

  disabledEffectiveTailscaleEvaluation = builtins.tryEval disabledEffectiveTailscale.config.system.build.toplevel.drvPath;

  sandflySudoRule = {
    users = [ "sandfly" ];
    commands = [
      {
        command = "ALL";
        options = [ "NOPASSWD" ];
      }
    ];
  };
in
assert validEvaluation.success;
assert !missingPolicyConfirmationEvaluation.success;
assert !disabledEffectiveTailscaleEvaluation.success;
assert lib.elem "--ssh" validCfg.services.tailscale.extraSetFlags;
assert validCfg.users.users.sandfly.hashedPassword == "!";
assert lib.elem sandflySudoRule validCfg.security.sudo.extraRules;
assert lib.hasInfix "/usr/local/bin/sudo" validCfg.system.activationScripts.sandflySudoCompat.text;
assert !(builtins.hasAttr "sandfly" snowfall.config.users.users);
pkgs.runCommand "sandfly-target-tests" { } "touch $out"
