{
  lib,
  config,
  inputs,
  self,
  VARS,
  ...
}:
let
  cfg = config.sys.home;
  timestamp = builtins.toString self.sourceInfo.lastModified;
in
{
  config = lib.mkIf cfg.enable {
    home-manager = {
      useGlobalPkgs = lib.mkDefault true;
      useUserPackages = lib.mkDefault true;
      backupFileExtension = lib.mkDefault "hm-backup-${timestamp}";

      sharedModules = [
        inputs.sops-nix.homeManagerModules.sops
        inputs.hyprland.homeManagerModules.default
        inputs.quadlet-nix.homeManagerModules.quadlet
      ];

      extraSpecialArgs = {
        inherit inputs VARS;
        inherit (config.networking) hostName;
      };
    };
  };
}
