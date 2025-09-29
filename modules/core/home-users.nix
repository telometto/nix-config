{
  lib,
  config,
  pkgs,
  VARS,
  ...
}:
let
  cfg = config.telometto.home;

  # Get system users from either systemUsers or VARS
  systemUsersSource = if cfg.systemUsers != { } then cfg.systemUsers else (VARS.users or { });

  systemUsers = lib.listToAttrs (
    map
      (userCfg: {
        name = userCfg.user;
        value = userCfg;
      })
      (
        lib.filter (userCfg: (userCfg ? user) && (userCfg.isNormalUser or false)) (
          builtins.attrValues systemUsersSource
        )
      )
  );

  # Auto-enable desktop flavor based on system config
  autoDesktopConfig =
    let
      flavor = config.telometto.desktop.flavor or null;
    in
    lib.optionalAttrs
      (
        flavor != null
        && builtins.elem flavor [
          "kde"
          "gnome"
          "hyprland"
        ]
      )
      {
        hm.desktop.${flavor}.enable = lib.mkDefault true;
      };

  # Collect all imports from various sources
  collectImports =
    username: _:
    let
      override = lib.attrByPath [ username ] cfg.users { };
      hostOverridePath = ../../home/users/host-overrides/${config.networking.hostName}.nix;
      hostOverride =
        if builtins.pathExists hostOverridePath then
          import hostOverridePath {
            inherit
              lib
              config
              pkgs
              VARS
              ;
          }
        else
          { };
    in
    lib.unique (
      [ ../../hm-loader.nix ]
      ++ cfg.extraModules
      ++ lib.toList (cfg.template.imports or [ ])
      ++ lib.toList (hostOverride.imports or [ ])
      ++ lib.toList (override.extraModules or [ ])
      ++ lib.toList (override.extraConfig.imports or [ ])
    );

  # Build user configuration by merging all sources
  buildUserConfig =
    username: userAttrs:
    let
      override = lib.attrByPath [ username ] cfg.users { };
      hostOverridePath = ../../home/users/host-overrides/${config.networking.hostName}.nix;
      hostOverride =
        if builtins.pathExists hostOverridePath then
          import hostOverridePath {
            inherit
              lib
              config
              pkgs
              VARS
              ;
          }
        else
          { };
      homeDir = userAttrs.home or userAttrs.homeDirectory or "/home/${username}";
    in
    {
      imports = collectImports username userAttrs;
    }
    // lib.foldl' lib.recursiveUpdate { } [
      (builtins.removeAttrs cfg.template [ "imports" ])
      (builtins.removeAttrs hostOverride [ "imports" ])
      (builtins.removeAttrs (override.extraConfig or { }) [ "imports" ])
      autoDesktopConfig
      {
        home.username = lib.mkDefault username;
        home.homeDirectory = lib.mkDefault homeDir;
      }
    ];

  # Check for users defined in cfg.users but not in system users
  missingUsers = lib.filter (username: !(lib.hasAttr username systemUsers)) (
    builtins.attrNames cfg.users
  );
in
{
  config = lib.mkIf cfg.enable {
    # Warn about users defined in cfg.users but not in system
    warnings = map (
      username:
      "telometto.home.users.${username} is defined, but there is no matching NixOS user. Home Manager configuration will be skipped."
    ) missingUsers;

    home-manager.users = lib.mapAttrs (
      username: userAttrs:
      let
        override = lib.attrByPath [ username ] cfg.users { };
        userEnabled = override.enable or true;
      in
      lib.mkIf userEnabled (buildUserConfig username userAttrs)
    ) systemUsers;
  };
}
