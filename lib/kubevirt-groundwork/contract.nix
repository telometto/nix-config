# This narrow contract bounds the selective-CI registration-only exception.
{ lib, catalog }:
let
  disks = profile: [ "root" ] ++ map (volume: volume.name) profile.stateVolumes;
  canonical = profile: {
    sys.virtualisation.actualPilot.previewVMs.${profile.namespace} = {
      enable = lib.mkDefault false;
      disks = disks profile;
    };
  };
  isCanonical =
    profile: value:
    let
      result = builtins.tryEval (builtins.deepSeq value (value == canonical profile));
    in
    result.success && result.value;
  modulePath = root: profile: root + "/hosts/blizzard/virtualisation/${profile.id}-preview.nix";
  # Exact source also forbids functions whose behavior changes when NixOS
  # supplies config/options/pkgs arguments. Value-only equality cannot do that.
  canonicalText =
    profile:
    "# Fresh preview disks only; runtime and Flux stay gated separately.\n"
    + "{ lib, ... }:\n{\n"
    + "  sys.virtualisation.actualPilot.previewVMs.${profile.namespace} = {\n"
    + "    enable = lib.mkDefault false;\n"
    + "    disks = [\n"
    + builtins.concatStringsSep "" (map (disk: "      ${builtins.toJSON disk}\n") (disks profile))
    + "    ];\n  };\n}\n";
  realDirectory = root: name: (builtins.readDir root).${name} or null == "directory";
  profiles = catalog.services;
in
{
  inherit
    canonicalText
    canonical
    isCanonical
    disks
    modulePath
    ;
  inspect =
    root:
    let
      present = builtins.filter (p: builtins.pathExists (modulePath root p)) profiles;
      realParents =
        realDirectory root "hosts"
        && realDirectory (root + "/hosts") "blizzard"
        && realDirectory (root + "/hosts/blizzard") "virtualisation";
      entries = if realParents then builtins.readDir (root + "/hosts/blizzard/virtualisation") else { };
      valid =
        realParents
        && builtins.all (
          p:
          entries.${p.id + "-preview.nix"} or null == "regular"
          && builtins.readFile (modulePath root p) == canonicalText p
          && isCanonical p ((import (modulePath root p)) { inherit lib; })
        ) present;
    in
    {
      inherit valid;
      files = map (modulePath root) present;
      namespaces = map (p: p.namespace) present;
    };
}
