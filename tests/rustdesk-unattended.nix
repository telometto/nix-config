{ pkgs }:
let
  evaluate =
    extra:
    (import (pkgs.path + "/nixos/lib/eval-config.nix") {
      inherit pkgs;
      system = pkgs.stdenv.hostPlatform.system;
      modules = [
        { system.stateVersion = "26.05"; }
        ../modules/services/rustdesk-unattended.nix
        extra
      ];
    }).config;
  disabled = evaluate { };
  enabled = evaluate { sys.services.rustdeskUnattended.enable = true; };
  # Verify that selecting a package changes both the system install and service.
  overridden = evaluate {
    sys.services.rustdeskUnattended = {
      enable = true;
      package = pkgs.hello;
    };
  };
in
assert !(disabled.systemd.services ? rustdesk);
assert enabled.systemd.services.rustdesk.serviceConfig.User == "root";
assert builtins.elem "uinput" enabled.boot.kernelModules;
assert builtins.elem "multi-user.target" enabled.systemd.services.rustdesk.wantedBy;
assert builtins.elem "drm" enabled.sys.services.rustdeskUnattended.package.cargoBuildFeatures;
assert builtins.elem "drm-wake" enabled.sys.services.rustdeskUnattended.package.cargoBuildFeatures;
assert
  overridden.systemd.services.rustdesk.serviceConfig.ExecStart == "${pkgs.hello}/bin/hello --service";
assert builtins.elem pkgs.hello overridden.environment.systemPackages;
pkgs.runCommand "rustdesk-unattended-module-check" { } ''
  touch "$out"
''
