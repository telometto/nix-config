{ lib, ... }:
let
  paths = lib.filesystem.listFilesRecursive ./home;

  isHostOverride = path: lib.strings.hasInfix "/host-overrides/" (toString path);

  isNixFile = path: lib.strings.hasSuffix ".nix" (toString path);

  regularModules = lib.filter (path: (isNixFile path) && !(isHostOverride path)) paths;
in
{
  imports = regularModules;
}
