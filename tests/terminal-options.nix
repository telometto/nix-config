{ pkgs, hmStable }:
let
  inherit (pkgs) lib;
  hm = import "${hmStable}/lib" { inherit lib; };
  make =
    terminal:
    (hm.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        ../home/programs/terminal.nix
        {
          options.hm.programs.fastfetch.enable = lib.mkEnableOption "fixture fastfetch";
          config = {
            home = {
              username = "terminal-fixture";
              homeDirectory = "/tmp/terminal-fixture";
              stateVersion = "26.05";
            };
            programs.ssh.enableDefaultConfig = false;
            hm.programs.terminal = terminal;
          };
        }
      ];
    }).config;
  defaults = make { enable = true; };
  configured = make {
    enable = true;
    extraPackages = [ pkgs.hello ];
    zellij.enable = false;
  };
  disabled = make {
    extraPackages = [ pkgs.hello ];
  };
  hasHello = cfg: lib.any (package: lib.getName package == "hello") cfg.home.packages;
in
{
  extraPackagesInstalled = hasHello configured;
  zellijEnabledByDefault = defaults.programs.zellij.enable;
  zellijCanBeDisabled = !configured.programs.zellij.enable;
  disabledModuleAddsNoPackages = !(hasHello disabled);
  disabledModuleDoesNotEnableZellij = !disabled.programs.zellij.enable;
}
