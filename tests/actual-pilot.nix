# This test imports only public nixpkgs and the pilot module, never the host flake.
{
  nixpkgs,
  system ? "x86_64-linux",
}:
let
  pkgs = import nixpkgs { inherit system; };
  inherit (pkgs) lib;
  make =
    enabled:
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
      ];
    };
  off = (make false).config;
  on = (make true).config;
  preview =
    ((make true).extendModules {
      modules = [ { sys.virtualisation.actualPilot.previewVMs.searx-preview.enable = true; } ];
    }).config;
  disabled =
    ((make true).extendModules {
      modules = [ { sys.virtualisation.actualPilot.previewVMs.searx-preview = { }; } ];
    }).config;
  searxHost =
    ((make true).extendModules {
      modules = [ ../hosts/blizzard/virtualisation/searx-preview.nix ];
    }).config;
  invalid =
    name: disks:
    ((make true).extendModules {
      modules = [
        {
          sys.virtualisation.actualPilot.previewVMs.${name} = {
            enable = true;
            inherit disks;
          };
        }
      ];
    }).config;
  invalidPreview = name: disks: builtins.any (a: !a.assertion) (invalid name disks).assertions;
  settings = builtins.fromJSON (
    builtins.unsafeDiscardStringContext on.environment.etc."k3s-actual-pilot/config.json".text
  );
in
assert
  preview.sys.virtualisation.actualPilot.preflightConfig.previewDiskDirs
  == [ "/flash/enc/vms/kubevirt-pilot/searx-preview/root" ];
assert
  preview.sys.virtualisation.actualPilot.preflightConfig.diskDirs
  == on.sys.virtualisation.actualPilot.preflightConfig.diskDirs
  ++ preview.sys.virtualisation.actualPilot.preflightConfig.previewDiskDirs;
assert !(on.sys.virtualisation.actualPilot.preflightConfig ? previewDiskDirs);
assert
  disabled.sys.virtualisation.actualPilot.preflightConfig
  == on.sys.virtualisation.actualPilot.preflightConfig;
assert disabled.systemd.services.k3s.preStart == on.systemd.services.k3s.preStart;
assert preview.services.traefik == on.services.traefik;
assert
  preview.systemd.services."microvm@production-probe".serviceConfig
  == on.systemd.services."microvm@production-probe".serviceConfig;
assert !searxHost.sys.virtualisation.actualPilot.previewVMs.searx-preview.enable;
assert searxHost.sys.virtualisation.actualPilot.previewVMs.searx-preview.disks == [ "root" ];
assert
  searxHost.sys.virtualisation.actualPilot.preflightConfig
  == on.sys.virtualisation.actualPilot.preflightConfig;
assert searxHost.services.traefik == on.services.traefik;
assert
  searxHost.systemd.services."microvm@production-probe".serviceConfig
  == on.systemd.services."microvm@production-probe".serviceConfig;
assert invalidPreview "../actual" [ "root" ];
assert invalidPreview "actual" [ "root" ];
assert invalidPreview "restore-tests" [ "root" ];
assert invalidPreview "safe-preview" [ "../data" ];
assert invalidPreview "safe-preview" [
  "root"
  "root"
];
assert invalidPreview "safe-preview" [ ];
assert !off.services.k3s.enable;
assert !(off.systemd.services ? actual-pilot-bootstrap);
assert !(off.systemd.services ? actual-pilot-firewall);
assert on.services.k3s.enable;
assert on.services.k3s.package.version == "1.35.10+k3s1";
assert settings."data-dir" == "/var/lib/rancher/k3s-actual-pilot";
assert settings."write-kubeconfig" == "/etc/rancher/k3s-actual-pilot/k3s.yaml";
assert settings."write-kubeconfig-mode" == "0600";
assert settings."cluster-cidr" == "10.44.0.0/16";
assert settings."service-cidr" == "10.45.0.0/16";
assert settings."cluster-dns" == "10.45.0.10";
assert settings."flannel-backend" == "vxlan";
assert settings."private-registry" == "/etc/k3s-actual-pilot/registries.json";
assert on.environment.etc."k3s-actual-pilot/registries.json".text == "{}";
assert
  settings."image-credential-provider-config" == "/etc/k3s-actual-pilot/no-credential-providers.yaml";
assert lib.hasPrefix "/nix/store/" settings."image-credential-provider-bin-dir";
assert !(on.environment.etc ? "k3s-actual-pilot/no-credential-providers.yaml");
assert !(settings."disable-kube-proxy" or false);
assert !(settings."disable-network-policy" or false);
assert lib.elem "traefik" on.services.k3s.disable;
assert lib.elem "servicelb" on.services.k3s.disable;
assert on.services.k3s.manifests == { };
assert on.services.k3s.containerdConfigTemplate == null;
assert (on.services.k3s.containerdConfigTemplateV3 or null) == null;
assert on.networking.firewall.enable;
assert on.networking.firewall.checkReversePath == off.networking.firewall.checkReversePath;
assert on.networking.firewall.trustedInterfaces == off.networking.firewall.trustedInterfaces;
assert on.networking.firewall.allowedTCPPorts == off.networking.firewall.allowedTCPPorts;
assert
  on.networking.firewall.interfaces.cni0.allowedTCPPorts == [
    6443
    10250
  ];
assert on.services.traefik.enable == off.services.traefik.enable;
assert
  on.systemd.services."microvm@production-probe".serviceConfig
  == off.systemd.services."microvm@production-probe".serviceConfig;
assert
  on.systemd.services.actual-pilot-bootstrap.environment.KUBECONFIG == settings."write-kubeconfig";
assert on.systemd.services.actual-pilot-bootstrap.serviceConfig.TimeoutStartSec != "infinity";
assert lib.elem "actual-pilot-firewall.service" on.systemd.services.k3s.requires;
assert lib.elem "actual-pilot-firewall.service" on.systemd.services.k3s.after;
assert lib.elem "firewall.service" on.systemd.services.actual-pilot-firewall.after;
assert lib.hasInfix "actual_pilot_preflight.py" on.systemd.services.k3s.preStart;
assert on.systemd.services.k3s.unitConfig.RequiresMountsFor == [ "/flash/enc/vms" ];
assert lib.hasInfix "priority -90" on.sys.virtualisation.actualPilot.firewallRules;
assert lib.hasInfix "fib daddr type local" on.sys.virtualisation.actualPilot.firewallRules;
assert !(on.systemd.services.actual-pilot-firewall.serviceConfig ? ExecStop);
{
  passed = true;
  checks = 59;
  configFile = on.environment.etc."k3s-actual-pilot/config.json".source;
  bootstrap = on.systemd.services.actual-pilot-bootstrap.serviceConfig.ExecStart;
  k3sExecStart = on.systemd.services.k3s.serviceConfig.ExecStart;
  firewallRules = pkgs.writeText "actual-pilot-control-test.nft" on.sys.virtualisation.actualPilot.firewallRules;
}
