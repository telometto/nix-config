{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.sys.security.kwalletTpm;
  package = pkgs.callPackage ../../packages/kwallet-tpm {
    allowedUsers = cfg.users;
    systemd = config.systemd.package;
    inherit (cfg) pcrs;
  };
  auth = config.security.pam.services.sddm-autologin.rules.auth;
  baseOrder = auth.permit.order;
  handoffNames = [
    "kwallet-tpm-token"
    "kwallet-tpm-wallet"
    "kwallet-tpm-clear"
  ];
in
{
  options.sys.security.kwalletTpm = {
    enable = lib.mkEnableOption "TPM-backed KWallet unlocking during SDDM automatic login";
    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "gianluca" ];
      description = "Local normal users allowed to enroll a TPM-protected kdewallet password.";
    };
    pcrs = lib.mkOption {
      type = lib.types.listOf (lib.types.ints.between 0 23);
      default = [
        4
        7
      ];
      description = ''
        TPM PCR indexes required for credential release. PCRs 4 (boot executable
        measurements) and 7 (Secure Boot policy) are mandatory. Additional PCRs
        may require more frequent re-enrollment. A boot/kernel update can change
        PCR 4; enroll locally after booting the intended generation.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion =
          config.services.desktopManager.plasma6.enable
          && config.services.displayManager.sddm.enable
          && config.services.displayManager.autoLogin.enable;
        message = "sys.security.kwalletTpm: requires Plasma 6 and SDDM automatic login.";
      }
      {
        assertion =
          cfg.users != [ ]
          && lib.all (
            user:
            builtins.match "[a-zA-Z_][a-zA-Z0-9_.-]*\\$?" user != null
            && builtins.stringLength user <= 128
            && (config.users.users.${user}.isNormalUser or false)
          ) cfg.users;
        message = "sys.security.kwalletTpm: users must be valid existing local normal users.";
      }
      {
        assertion = lib.elem config.services.displayManager.autoLogin.user cfg.users;
        message = "sys.security.kwalletTpm: the SDDM automatic-login user must be allowlisted.";
      }
      {
        assertion = lib.elem 4 cfg.pcrs && lib.elem 7 cfg.pcrs;
        message = "sys.security.kwalletTpm: PCRs 4 and 7 must remain in the credential policy.";
      }
      {
        assertion = config.security.pam.services.login.kwallet.enable;
        message = "sys.security.kwalletTpm: the inherited login KWallet session hook must be enabled.";
      }
      {
        assertion = lib.all (
          rule:
          !rule.enable
          || rule.order <= baseOrder
          || rule.order > baseOrder + 30
          || lib.elem rule.name handoffNames
        ) (lib.attrValues auth);
        message = "sys.security.kwalletTpm: another auth rule interrupts the adjacent wallet handoff.";
      }
    ];

    environment.systemPackages = [ package ];
    systemd.tmpfiles.rules = [ "d /var/lib/kwallet-tpm 0700 root root - -" ];
    security.pam.services.login.kwallet.enable = lib.mkDefault true;

    # NixOS PAM rules are experimental. Their ordering/shape must be checked
    # on nixpkgs updates; tests/kwallet-tpm.nix pins the rendered stack contract.
    security.pam.services.sddm-autologin.rules.auth = {
      kwallet-tpm-token = {
        order = baseOrder + 10;
        # A failed/missing decrypt skips only the adjacent optional wallet hook.
        # In particular it must not invoke KDE's interactive password fallback.
        control = "[success=ok default=1]";
        modulePath = "${package}/lib/security/pam_kwallet_tpm.so";
      };
      kwallet-tpm-wallet = {
        order = baseOrder + 20;
        control = "optional";
        modulePath = "${config.security.pam.services.login.kwallet.package}/lib/security/pam_kwallet5.so";
      };
      kwallet-tpm-clear = {
        order = baseOrder + 30;
        control = "optional";
        modulePath = "${package}/lib/security/pam_kwallet_tpm.so";
        args = [ "clear" ];
      };
    };
  };
}
