{
  lib,
  config,
  inputs,
  VARS,
  ...
}:
let
  cfg = config.sys.home;
in
{
  config = lib.mkIf cfg.enable {
    home-manager = {
      useGlobalPkgs = lib.mkDefault true;
      useUserPackages = lib.mkDefault true;
      backupFileExtension = lib.mkDefault "hm-backup-${config.system.nixos.label}";

      sharedModules = [
        inputs.sops-nix.homeManagerModules.sops
        inputs.hyprland.homeManagerModules.default
      ];

      extraSpecialArgs = {
        inherit inputs VARS;
        inherit (config.networking) hostName;
      };
    };
  };
}
