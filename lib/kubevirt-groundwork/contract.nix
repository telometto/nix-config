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
  profiles = catalog.services;
in
{
  inherit
    canonical
    isCanonical
    disks
    modulePath
    ;
  inspect =
    root:
    let
      present = builtins.filter (p: builtins.pathExists (modulePath root p)) profiles;
      valid = builtins.all (p: isCanonical p ((import (modulePath root p)) { inherit lib; })) present;
    in
    {
      inherit valid;
      files = map (modulePath root) present;
      namespaces = map (p: p.namespace) present;
    };
}
