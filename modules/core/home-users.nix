{
  lib,
  config,
  pkgs,
  VARS,
  ...
}:
let
  cfg = config.telometto.home;

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

  systemUserNames = builtins.attrNames systemUsersSource;

  systemUserCfg = name: lib.attrByPath [ name ] systemUsersSource { };

  missingUserAttr = lib.filter (name: !(systemUserCfg name ? user)) systemUserNames;

  disabledSystemUsers = lib.filter (
    name:
    let
      userCfg = systemUserCfg name;
    in
    (userCfg ? user) && !(userCfg.isNormalUser or false)
  ) systemUserNames;

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
      hostPerUser = lib.attrByPath [ "perUser" username ] hostOverride { };
    in
    lib.unique (
      [ ../../hm-loader.nix ]
      ++ cfg.extraModules
      ++ lib.toList (cfg.template.imports or [ ])
      # Host overrides can expose shared modules via `imports` and per-user modules via `perUser.<name>.imports`.
      ++ lib.toList (hostOverride.imports or [ ])
      ++ lib.toList (hostPerUser.imports or [ ])
      ++ lib.toList (override.extraModules or [ ])
      ++ lib.toList (override.extraConfig.imports or [ ])
    );

  # Build user configuration by merging all sources
  buildUserConfig =
    username: userAttrs:
    let
      override = lib.attrByPath [ username ] cfg.users { };
      systemUserHome =
        let
          systemUser = lib.attrByPath [ username ] config.users.users null;
        in
        if systemUser != null && systemUser ? home then systemUser.home else null;
      preferredHomes = [
        (userAttrs.home or null)
        (userAttrs.homeDirectory or null)
        systemUserHome
        "/home/${username}"
      ];
      homeDir = lib.findFirst (home: home != null) preferredHomes "/home/${username}";
      hostPerUser = lib.attrByPath [ "perUser" username ] hostOverride { };
      hostGlobalConfig = builtins.removeAttrs hostOverride [
        "imports"
        "perUser"
      ];
      hostPerUserConfig = builtins.removeAttrs hostPerUser [ "imports" ];
    in
    {
      imports = collectImports username userAttrs;
    }
    // lib.foldl' lib.recursiveUpdate { } [
      (builtins.removeAttrs cfg.template [ "imports" ])
      hostGlobalConfig
      hostPerUserConfig
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
    warnings =
      (map (
        username:
        "telometto.home.users.${username} is defined, but there is no matching NixOS user. Home Manager configuration will be skipped."
      ) missingUsers)
      ++ (map (
        name:
        "telometto.home.systemUsers.${name} is missing the `user` attribute; Home Manager configuration will be skipped."
      ) missingUserAttr)
      ++ (map (
        name:
        let
          userCfg = systemUserCfg name;
          username = userCfg.user or name;
        in
        "Home Manager configuration for ${username} is skipped because isNormalUser is not true."
      ) disabledSystemUsers);

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
