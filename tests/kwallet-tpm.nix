{ pkgs }:
let
  inherit (pkgs) lib;
  # The dispatcher is real Linux PAM; exclude kernel audit transport in the
  # hermetic build sandbox. The normal audited PAM is also tested locally.
  fixturePam = pkgs.pam.override { withAudit = false; };
  evaluate =
    settings:
    (import (pkgs.path + "/nixos/lib/eval-config.nix") {
      inherit pkgs;
      system = pkgs.stdenv.hostPlatform.system;
      modules = [
        ../modules/security/kwallet-tpm.nix
        {
          networking.hostName = "fixture";
          services.desktopManager.plasma6.enable = true;
          services.displayManager.sddm.enable = true;
          services.displayManager.autoLogin = {
            enable = true;
            user = "fixture";
          };
          users.users.fixture = {
            isNormalUser = true;
            uid = 1000;
          };
          users.users.other = {
            isNormalUser = true;
            uid = 1001;
          };
          system.stateVersion = "26.05";
        }
        settings
      ];
    }).config;
  bareDisabled =
    (import (pkgs.path + "/nixos/lib/eval-config.nix") {
      inherit pkgs;
      modules = [
        ../modules/security/kwallet-tpm.nix
        { system.stateVersion = "26.05"; }
      ];
    }).config;
  disabled = evaluate { };
  enabled = evaluate {
    sys.security.kwalletTpm = {
      enable = true;
      users = [ "fixture" ];
    };
  };
  other = evaluate {
    networking.hostName = lib.mkForce "another-host";
    services.displayManager.autoLogin.user = lib.mkForce "other";
    sys.security.kwalletTpm = {
      enable = true;
      users = [ "other" ];
    };
  };
  rules = enabled.security.pam.services.sddm-autologin.rules.auth;
  # Force the actual renderer and the inherited session chain, not only rule attrs.
  renderedLines =
    service:
    map (line: builtins.head (lib.splitString " #" line)) (
      lib.splitString "\n" enabled.security.pam.services.${service}.text
    );
  renderedAutologin = renderedLines "sddm-autologin";
  expectedHandoff = [
    "auth [success=ok default=1] ${rules.kwallet-tpm-token.modulePath}"
    "auth optional ${rules.kwallet-tpm-wallet.modulePath}"
    "auth optional ${rules.kwallet-tpm-clear.modulePath} clear"
  ];
  moduleValid =
    config:
    lib.all (a: a.assertion || !(lib.hasPrefix "sys.security.kwalletTpm:" a.message)) config.assertions;
  invalidPolicy = evaluate {
    sys.security.kwalletTpm = {
      enable = true;
      users = [ "fixture" ];
      pcrs = [ 7 ];
    };
  };
  invalidUser = evaluate {
    sys.security.kwalletTpm = {
      enable = true;
      users = [ "root" ];
    };
  };
  package = lib.findFirst (
    p: (p.pname or "") == "kwallet-tpm"
  ) (throw "enabled module did not install enrollment") enabled.environment.systemPackages;
in
assert !(bareDisabled.security.pam.services ? sddm-autologin);
assert !(disabled.security.pam.services.sddm-autologin.rules.auth ? kwallet-tpm-token);
assert moduleValid enabled && moduleValid other;
assert !(moduleValid invalidPolicy) && !(moduleValid invalidUser);
assert lib.any (i: lib.sublist i 3 renderedAutologin == expectedHandoff) (
  lib.range 0 (builtins.length renderedAutologin - 3)
);
assert lib.elem "session include sddm" (renderedLines "sddm-autologin");
assert lib.elem "session include login" (renderedLines "sddm");
assert lib.elem
  "session optional ${enabled.security.pam.services.login.kwallet.package}/lib/security/pam_kwallet5.so"
  (renderedLines "login");
assert rules.kwallet-tpm-token.order == rules.permit.order + 10;
assert rules.kwallet-tpm-wallet.order == rules.kwallet-tpm-token.order + 10;
assert rules.kwallet-tpm-clear.order == rules.kwallet-tpm-wallet.order + 10;
assert rules.kwallet-tpm-token.control == "[success=ok default=1]";
assert rules.kwallet-tpm-wallet.control == "optional";
assert rules.kwallet-tpm-clear.control == "optional";
assert rules.kwallet-tpm-clear.args == [ "clear" ];
assert enabled.security.pam.services.login.text == disabled.security.pam.services.login.text;
assert enabled.security.pam.services.sddm.text == disabled.security.pam.services.sddm.text;
assert
  enabled.security.pam.services.sddm-autologin.rules.session
  == disabled.security.pam.services.sddm-autologin.rules.session;
assert lib.elem "d /var/lib/kwallet-tpm 0700 root root - -" enabled.systemd.tmpfiles.rules;
pkgs.runCommand "kwallet-tpm-tests"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.stdenv.cc
      package
    ];
    buildInputs = [ fixturePam ];
  }
  ''
    mkdir -p source/packages/kwallet-tpm source/tests
    cp ${../packages/kwallet-tpm/enroll.py} source/packages/kwallet-tpm/enroll.py
    cp ${../packages/kwallet-tpm/pam_kwallet_tpm.c} source/packages/kwallet-tpm/pam_kwallet_tpm.c
    cp ${./kwallet_tpm_test.py} source/tests/kwallet_tpm_test.py
    cp ${./kwallet_tpm_pam_fixture.c} source/tests/kwallet_tpm_pam_fixture.c
    export PAM_PREFIX=${fixturePam}
    python3 -B source/tests/kwallet_tpm_test.py
    kwallet-tpm-enroll --help >/dev/null
    test -r ${package}/lib/security/pam_kwallet_tpm.so
    touch "$out"
  ''
