{ lib, ... }:
let
  paths = lib.filesystem.listFilesRecursive ./home;

  # Exclude directories that contain host or user-specific configurations
  isHostOverride = path: lib.strings.hasInfix "/host-overrides/" (toString path);
  isUserConfig = path: lib.strings.hasInfix "/user-configs/" (toString path);

  isNixFile = path: lib.strings.hasSuffix ".nix" (toString path);

  # Only import regular modules, excluding host-overrides and user-configs
  regularModules = lib.filter (
    path: (isNixFile path) && !(isHostOverride path) && !(isUserConfig path)
  ) paths;
in
{
  imports = regularModules;
}
