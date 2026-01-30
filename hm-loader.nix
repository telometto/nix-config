{ lib, ... }:
let
  paths = lib.filesystem.listFilesRecursive ./home;

  # Exclude directories that contain host or user-specific configurations
  isHostOverride = path: lib.strings.hasInfix "/overrides/host/" (toString path);
  isUserConfig = path: lib.strings.hasInfix "/overrides/user/" (toString path);

  isNixFile = path: lib.strings.hasSuffix ".nix" (toString path);

  # Only import regular modules, excluding overrides/host and overrides/user
  regularModules = lib.filter (
    path: (isNixFile path) && !(isHostOverride path) && !(isUserConfig path)
  ) paths;
in
{
  imports = regularModules;
}
