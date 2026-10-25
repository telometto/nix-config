{
  nixpkgs,
  hmStable,
  hmMaster,
  system,
}:
let
  pkgs = import nixpkgs { inherit system; };
  hm = import "${hmStable}/lib" { inherit (pkgs) lib; };
  compatibility = import ./codex-adapter.nix {
    inherit
      nixpkgs
      hmStable
      hmMaster
      system
      ;
  };
  derivedPlugin = pkgs.runCommand "codex-test-plugin" { } ''
    cp -r ${./fixtures/codex-plugin} "$out"
  '';
  make =
    preferXdgDirectories: plugins:
    (hm.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs.inputs.hm-master = hmMaster;
      modules = [
        ../home/programs/codex.nix
        {
          home = {
            username = "codex-fixture";
            homeDirectory = "/tmp/codex-activation-fixture";
            stateVersion = "26.05";
            inherit preferXdgDirectories;
          };
          hm.programs.codex = {
            enable = true;
            package = null;
            mutableSettings = true;
            inherit plugins;
            settings = {
              model = "declared-model";
              mcp_servers = {
                to_stdio.command = "fixture-server";
                to_http.url = "https://example.invalid/mcp";
              };
            };
          };
        }
      ];
    }).config;
  fixtures = builtins.listToAttrs (
    map
      (
        xdg:
        let
          cfg = make xdg [ ./fixtures/codex-plugin ];
          derived = make xdg [ "${derivedPlugin}" ];
        in
        {
          name = if xdg then "xdg" else "legacy";
          value = {
            prefix = if xdg then ".config/codex" else ".codex";
            merge = cfg.home.activation.codexMutableSettings.data;
            staticCleanup = cfg.home.activation.cleanCodexPluginCache.data;
            derivedCleanup = derived.home.activation.cleanCodexPluginCache.data;
          };
        }
      )
      [
        false
        true
      ]
  );
  manifest = pkgs.writeText "codex-activation-fixtures.json" (
    builtins.toJSON {
      inherit fixtures;
      home = "/tmp/codex-activation-fixture";
      bashLibrary = "${hmStable}/lib/bash/home-manager.sh";
      storeTarget = "${hmStable}/flake.nix";
      mv = pkgs.lib.getExe' pkgs.coreutils "mv";
      cp = pkgs.lib.getExe' pkgs.coreutils "cp";
      chown = pkgs.lib.getExe' pkgs.coreutils "chown";
      setfacl = pkgs.lib.getExe' pkgs.acl "setfacl";
    }
  );
in
pkgs.runCommand "codex-adapter-tests"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.bash
      pkgs.acl
    ];
    passthru = { inherit manifest; };
  }
  ''
    mkdir -p "$out"
    # JSON serialization forces every assertion in all six compatibility cases.
    cp ${pkgs.writeText "codex-compatibility.json" (builtins.toJSON compatibility)} "$out/compatibility.json"
    python ${./codex_activation.py} ${manifest}
  ''
