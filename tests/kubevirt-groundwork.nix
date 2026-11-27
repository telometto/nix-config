# Public metadata-only contract. Does not import the host flake or credentials.
{
  nixpkgs,
  system ? "x86_64-linux",
  root ? ../.,
}:
let
  pkgs = import nixpkgs { inherit system; };
  inherit (pkgs) lib;
  catalog = builtins.fromJSON (builtins.readFile ../lib/kubevirt-groundwork/catalog.json);
  registry = import ../lib/kubevirt-groundwork/contract.nix { inherit lib catalog; };
  actual = registry.inspect root;
  profiles = catalog.services;
  make =
    enabled: imports:
    import (nixpkgs + "/nixos/lib/eval-config.nix") {
      inherit system;
      modules = [
        ../modules/virtualisation/actual-pilot.nix
        {
          system.stateVersion = "26.05";
          networking.hostName = "blizzard";
          services.traefik.enable = true;
          systemd.services."microvm@production-probe".serviceConfig.ExecStart = "/production/runner";
          sys.virtualisation.actualPilot = lib.mkIf enabled {
            enable = true;
            nodeIP = "192.168.2.100";
          };
        }
      ]
      ++ imports;
    };
  baseline = (make true [ ]).config;
  registered = (make true actual.files).config;
  offBaseline = (make false [ ]).config;
  offRegistered = (make false actual.files).config;
  allDisabled = (make true (map registry.canonical profiles)).config;
  allEnabled =
    (make true (
      map (p: {
        sys.virtualisation.actualPilot.previewVMs.${p.namespace} = {
          enable = true;
          disks = registry.disks p;
        };
      }) profiles
    )).config;
  paths = lib.concatMap (
    p: map (d: "/flash/enc/vms/kubevirt-pilot/${p.namespace}/${d}") (registry.disks p)
  ) profiles;
  names = map (p: p.id) profiles;
  profile = builtins.head profiles;
  changedEnable = {
    sys.virtualisation.actualPilot.previewVMs.${profile.namespace} = {
      enable = true;
      disks = registry.disks profile;
    };
  };
  extraEffect = registry.canonical profile // {
    services.openssh.enable = true;
  };
  unchanged =
    current: original:
    current.sys.virtualisation.actualPilot.preflightConfig
    == original.sys.virtualisation.actualPilot.preflightConfig
    && current.systemd.services.k3s.preStart == original.systemd.services.k3s.preStart
    && current.services.traefik == original.services.traefik
    && current.networking.firewall == original.networking.firewall
    &&
      current.systemd.services."microvm@production-probe".serviceConfig
      == original.systemd.services."microvm@production-probe".serviceConfig;
in
assert catalog.schemaVersion == 1;
assert builtins.length names == 16 && builtins.length (lib.unique names) == 16;
assert !(builtins.elem "tautulli" names);
assert actual.valid;
assert !(registry.isCanonical profile changedEnable);
assert !(registry.isCanonical profile extraEffect);
assert unchanged registered baseline;
assert unchanged allDisabled baseline;
assert !offRegistered.services.k3s.enable;
assert
  builtins.attrNames offRegistered.systemd.services
  == builtins.attrNames offBaseline.systemd.services;
assert
  offRegistered.systemd.services."microvm@production-probe".serviceConfig
  == offBaseline.systemd.services."microvm@production-probe".serviceConfig;
assert offRegistered.services.traefik == offBaseline.services.traefik;
assert offRegistered.networking.firewall == offBaseline.networking.firewall;
assert
  lib.sort builtins.lessThan allEnabled.sys.virtualisation.actualPilot.preflightConfig.previewDiskDirs
  == lib.sort builtins.lessThan paths;
assert builtins.length paths == builtins.length (lib.unique paths);
assert builtins.all (
  p: p.namespace == "${p.id}-preview" && builtins.stringLength p.namespace <= 63
) profiles;
assert builtins.all (
  p: builtins.all (d: builtins.match "[a-z0-9]([a-z0-9-]*[a-z0-9])?" d != null) (registry.disks p)
) profiles;
{
  passed = true;
  registered = actual.namespaces;
  profiles = names;
  expectedDiskDirs = paths;
}
