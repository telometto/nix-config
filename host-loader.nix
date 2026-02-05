{
  lib,
  hostname,
  ...
}:
let
  hostPath = ./hosts/${hostname};
  paths = lib.filesystem.listFilesRecursive hostPath;

  isNixFile = path: lib.strings.hasSuffix ".nix" (toString path);
in
{
  imports = lib.filter isNixFile paths;
}
