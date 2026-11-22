{ lib, ... }:
let
  paths = lib.filesystem.listFilesRecursive ./home;

  # Exclude directories that contain host, user, or role-specific configurations
  isHostOverride = path: lib.strings.hasInfix "/overrides/host/" (toString path);
  isUserConfig = path: lib.strings.hasInfix "/overrides/user/" (toString path);
  isRoleOverride = path: lib.strings.hasInfix "/overrides/role/" (toString path);

  isNixFile = path: lib.strings.hasSuffix ".nix" (toString path);

  # Only import regular modules, excluding overrides/host, overrides/user, and overrides/role
  regularModules = lib.filter (
    path: (isNixFile path) && !(isHostOverride path) && !(isUserConfig path) && !(isRoleOverride path)
  ) paths;
in
{
  imports = regularModules;
}
