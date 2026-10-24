# Public-only evaluation; no runtime files are read or activated.
# nix eval --offline --impure --json --expr '
#   let
#     lock = builtins.fromJSON (builtins.readFile ./flake.lock);
#     source = name: builtins.fetchTree lock.nodes.${name}.locked;
#   in import ./tests/codex-adapter.nix {
#     nixpkgs = source "nixpkgs";
#     hmStable = source "hm-stable";
#     hmMaster = source "hm-master";
#   }'
{
  nixpkgs,
  hmStable,
  hmMaster,
  system ? builtins.currentSystem,
}:
let
  pkgs = import nixpkgs { inherit system; };
  inherit (pkgs) lib;
  hm = import "${hmStable}/lib" { inherit lib; };
  homeDirectory = "/tmp/codex-adapter-fixture-home";
  aliasValues = {
    package = null;
    mutableSettings = true;
    enableMcpIntegration = true;
    settings.model = "adapter-fixture";
    profiles.review.model = "profile-fixture";
    context = "Fixture context";
    contextOverride = "Fixture override";
    hooks.SessionStart = [
      {
        hooks = [
          {
            type = "command";
            command = "true";
          }
        ];
      }
    ];
    plugins = [ ./fixtures/codex-plugin ];
    marketplaces.fixture = ./fixtures/codex-plugin;
    skills.fixture = "# Fixture skill\n";
    rules.fixture = "prefix_rule(pattern = [\"true\"], decision = \"allow\")\n";
  };
  make =
    codex:
    (hm.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs.inputs.hm-master = hmMaster;
      modules = [
        ../home/programs/codex.nix
        {
          home = {
            username = "adapter-fixture";
            inherit homeDirectory;
            stateVersion = "26.05";
            preferXdgDirectories = true;
          };
          programs.mcp = {
            enable = true;
            servers.fixture.command = "fixture-server";
          };
          hm.programs.codex = codex;
        }
      ];
    }).config;
  enabled =
    preferXdg: mutable:
    let
      cfg = make (
        aliasValues
        // {
          enable = true;
          mutableSettings = mutable;
        }
        // lib.optionalAttrs (preferXdg != null) { preferXdgDirectories = preferXdg; }
      );
      prefix = if preferXdg == false then ".codex" else ".config/codex";
      fileTargets = map (file: lib.removePrefix "/" file.target) (builtins.attrValues cfg.home.file);
      summary = {
        enabled = cfg.programs.codex.enable;
        aliases = lib.all (
          name: cfg.programs.codex.${name} == (aliasValues // { mutableSettings = mutable; }).${name}
        ) (builtins.attrNames aliasValues);
        globalXdgUnchanged = cfg.home.preferXdgDirectories;
        directory =
          (cfg.home.sessionVariables.CODEX_HOME or null)
          == (if preferXdg == false then null else "${homeDirectory}/.config/codex");
        settings =
          if mutable then
            lib.hasInfix "${homeDirectory}/${prefix}/config.toml" cfg.home.activation.codexMutableSettings.data
            && !(lib.elem "${prefix}/config.toml" fileTargets)
          else
            lib.elem "${prefix}/config.toml" fileTargets
            && builtins.hasAttr "codexImmutableSettings" cfg.home.activation
            && !(builtins.hasAttr "codexMutableSettings" cfg.home.activation);
        optionalFiles = lib.all (name: lib.elem "${prefix}/${name}" fileTargets) [
          "AGENTS.md"
          "AGENTS.override.md"
          "review.config.toml"
          "hooks.json"
          "skills/fixture"
          "rules/fixture.rules"
          "plugins/cache/home-manager/fixture/1.0.0"
        ];
        assertions = lib.all (entry: entry.assertion) cfg.assertions;
      };
    in
    assert lib.all (value: value) (builtins.attrValues summary);
    summary;
  disabled =
    codex:
    let
      cfg = make codex;
      summary = {
        disabled = !cfg.programs.codex.enable;
        noEnvironment = !(cfg.home.sessionVariables ? CODEX_HOME);
        noFiles = lib.all (
          file: !(lib.hasInfix "codex" file.target || lib.hasPrefix ".agents/plugins/" file.target)
        ) (builtins.attrValues cfg.home.file);
        noActivation = lib.all (name: !(lib.hasInfix "codex" (lib.toLower name))) (
          builtins.attrNames cfg.home.activation
        );
        assertions = lib.all (entry: entry.assertion) cfg.assertions;
      };
    in
    assert lib.all (value: value) (builtins.attrValues summary);
    summary;
in
{
  legacy = enabled false true;
  xdg = enabled true true;
  inheritedXdg = enabled null true;
  immutable = enabled true false;
  defaultDisabled = disabled { };
  configuredDisabled = disabled (aliasValues // { enable = false; });
}
