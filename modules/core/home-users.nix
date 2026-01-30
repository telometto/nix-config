{
  lib,
  config,
  pkgs,
  VARS,
  ...
}:
let
  cfg = config.sys.home;

  # Transform VARS.users from role-keyed to username-keyed
  varsUsersByUsername = lib.listToAttrs (
    map (userData: {
      name = userData.user;
      value = userData;
    }) (builtins.attrValues (VARS.users or { }))
  );

  # Use VARS as the source of truth for which users to configure
  # Filter to only normal users that are enabled on this host
  systemUsers = lib.filterAttrs (
    username: userData:
    (userData.isNormalUser or false) && (config.sys.users.${username}.enable or true)
  ) varsUsersByUsername;

  # Auto-enable desktop flavor based on system config
  autoDesktopConfig =
    let
      flavor = config.sys.desktop.flavor or null;
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

      # Path to host-specific override file
      hostOverridePath = ../../home/overrides/host/${config.networking.hostName}.nix;

      # Path to user-specific config file
      userConfigPath = ../../home/overrides/user/${username}-${config.networking.hostName}.nix;
    in
    lib.unique (
      [ ../../hm-loader.nix ]
      ++ cfg.extraModules
      ++ lib.toList (cfg.template.imports or [ ])
      # Import host-override if it exists (applies to all users on this host)
      ++ (lib.optional (builtins.pathExists hostOverridePath) hostOverridePath)
      # Import user-specific config if it exists (applies only to this user on this host)
      ++ (lib.optional (builtins.pathExists userConfigPath) userConfigPath)
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
      ];
      homeDir = lib.findFirst (home: home != null) "/home/${username}" preferredHomes;
    in
    {
      imports = collectImports username userAttrs;
    }
    // lib.foldl' lib.recursiveUpdate { } [
      (builtins.removeAttrs cfg.template [ "imports" ])
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
      "sys.home.users.${username} is defined, but there is no matching NixOS user. Home Manager configuration will be skipped."
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
