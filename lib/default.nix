{ lib }:
{
  # Auto-import all .nix files and directories in a path (excluding default.nix)
  # Usage: imports = mylib.scanPaths ./.;
  scanPaths =
    path:
    builtins.map (f: (path + "/${f}")) (
      builtins.attrNames (
        lib.attrsets.filterAttrs (
          name: type:
          (type == "directory")
          || ((name != "default.nix") && (lib.strings.hasSuffix ".nix" name))
        ) (builtins.readDir path)
      )
    );
}
