{ pkgs, rustdeskPkgs }:
let
  inherit (pkgs) lib;
  evaluate =
    enabled:
    import (pkgs.path + "/nixos/lib/eval-config.nix") {
      inherit pkgs;
      system = pkgs.stdenv.hostPlatform.system;
      specialArgs = {
        consts.tailscale.suffix = "example.invalid";
        inputs.nixpkgs-rustdesk.legacyPackages.${pkgs.stdenv.hostPlatform.system} = rustdeskPkgs;
      };
      # Deliberately omit Home Manager and private inputs.
      modules = [
        ../modules/services/rustdesk-unattended.nix
        ../modules/security/secrets.nix
        ../hosts/kaizer/rustdesk.nix
        {
          sys.services.rustdeskUnattended.enable = lib.mkForce enabled;
          sys.secrets.rustdeskServerPublicKeyFile = lib.mkIf enabled "/fixture/public-key";
        }
      ];
    };
  enabled = (evaluate true).config;
  disabled = (evaluate false).config;
  unit = enabled.systemd.services.rustdesk;
  package = enabled.sys.services.rustdeskUnattended.package;
  provision = pkgs.writeShellScript "rustdesk-provision-fixture" unit.preStart;
  source = package.src;
in
assert !(disabled.systemd.services ? rustdesk);
assert disabled.sys.secrets.rustdeskServerPublicKeyFile == null;
assert enabled.networking.firewall.interfaces.tailscale0.allowedTCPPorts == [ 21120 ];
assert !(lib.elem 21120 enabled.networking.firewall.allowedTCPPorts);
assert
  !(lib.elem 21120 (disabled.networking.firewall.interfaces.tailscale0.allowedTCPPorts or [ ]));
assert unit.serviceConfig.LoadCredential == [ "server-key:/fixture/public-key" ];
assert unit.serviceConfig.RuntimeDirectory == "rustdesk";
assert unit.serviceConfig.RuntimeDirectoryMode == "0755";
assert unit.serviceConfig.RuntimeDirectoryPreserve == "restart";
assert lib.elem ../hosts/kaizer/rustdesk-managed-settings.patch package.patches;
assert lib.elem "drm" package.cargoBuildFeatures;
assert lib.elem "drm-wake" package.cargoBuildFeatures;
assert unit.serviceConfig.ExecStart == "${lib.getExe package} --service";
pkgs.runCommand "rustdesk-managed-settings-tests"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.rustc
      pkgs.patch
      pkgs.stdenv.cc
    ];
  }
  ''
    mkdir -p source/libs/hbb_common/src runtime credentials
    cp ${source}/libs/hbb_common/src/config.rs source/libs/hbb_common/src/config.rs
    chmod u+w source/libs/hbb_common/src/config.rs
    patch --directory=source -p1 < ${../hosts/kaizer/rustdesk-managed-settings.patch}
    python3 ${./rustdesk_managed_settings_test.py} source/libs/hbb_common/src/config.rs
    python3 ${./rustdesk_server_config_test.py} ${../hosts/kaizer/rustdesk-server-config.py}

    printf 'synthetic-public-key\n' > credentials/server-key
    RUNTIME_DIRECTORY="$PWD/runtime" CREDENTIALS_DIRECTORY="$PWD/credentials" ${provision}
    printf 'blizzard.example.invalid\nsynthetic-public-key\n' > expected
    cmp expected runtime/server-options
    test "$(stat -c %a runtime/server-options)" = 644
    touch "$out"
  ''
