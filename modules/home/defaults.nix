{ pkgs-stable, system, inputs, VARS, host, hostUsers }:

{
  # This entire file is just a NixOS module. It is also a function 
  # that receives all arguments and returns a module config.

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";

    sharedModules = [
      inputs.sops-nix.homeManagerModules.sops
      inputs.hyprland.homeManagerModules.default
    ];

    extraSpecialArgs = {
      pkgs-stable = pkgs-stable;
      inherit inputs VARS;
    };

    users = pkgs.lib.genAttrs hostUsers.${host} (user:
      import ./hosts/${host}/home/users/${
        if user == VARS.users.admin.user 
        then "admin" 
        else "extra/${user}"
      }/home.nix
    );
  };
}
