{
  blizzard,
  jellyfinVm,
  pkgs,
}:
let
  inherit (pkgs) lib;
  host = blizzard.config;
  guest = jellyfinVm.config;
  stagedSettings = {
    vmServiceReady = false;
    vpsIPv4 = null;
    gpuPassthrough = {
      enable = false;
      pciFunctions = [ ];
    };
  };
  stagedHost =
    (blizzard.extendModules {
      specialArgs.jellyfinSettings = stagedSettings;
    }).config;
  stagedGuest =
    (jellyfinVm.extendModules {
      specialArgs.jellyfinSettings = stagedSettings;
    }).config;
  readySettings = stagedSettings // {
    vmServiceReady = true;
    vpsIPv4 = "100.99.88.77";
  };
  readyHost =
    (blizzard.extendModules {
      specialArgs.jellyfinSettings = readySettings;
    }).config;
  readyGuest =
    (jellyfinVm.extendModules {
      specialArgs.jellyfinSettings = readySettings;
    }).config;
  stagedWithVps =
    (blizzard.extendModules {
      specialArgs.jellyfinSettings = stagedSettings // {
        vpsIPv4 = "100.99.88.77";
      };
    }).config;
  gpuSettings = readySettings // {
    gpuPassthrough = {
      enable = true;
      pciFunctions = [
        "0000:03:00.0"
        "0000:03:00.1"
      ];
    };
  };
  gpuHost =
    (blizzard.extendModules {
      specialArgs.jellyfinSettings = gpuSettings;
    }).config;
  gpuGuest =
    (jellyfinVm.extendModules {
      specialArgs.jellyfinSettings = gpuSettings;
    }).config;
  reg = (import ../vms/vm-registry.nix { consts = import ../lib/constants.nix; }).jellyfin;
  stateVolume = lib.findFirst (
    volume: volume.mountPoint == "/var/lib/jellyfin"
  ) null stagedGuest.microvm.volumes;
  cacheVolume = lib.findFirst (
    volume: volume.mountPoint == "/var/cache/jellyfin"
  ) null stagedGuest.microvm.volumes;
  mediaShare = lib.findFirst (
    share: share.mountPoint == "/rpool/unenc/media/data/media"
  ) null stagedGuest.microvm.shares;
  importShare = lib.findFirst (
    share: share.mountPoint == "/mnt/host-jellyfin"
  ) null stagedGuest.microvm.shares;
  hasImportSudo =
    cfg:
    lib.any (
      rule:
      lib.elem "admin" rule.users
      && lib.any (
        command:
        command.command == "/run/current-system/sw/bin/jellyfin-import-state"
        && lib.elem "NOPASSWD" command.options
      ) rule.commands
    ) cfg.security.sudo.extraRules;
  hasImportProgram =
    cfg: lib.any (package: package.name == "jellyfin-import-state") cfg.environment.systemPackages;
in
assert reg.ip == "10.100.0.72" && reg.cid == 128 && reg.port == 8096;
assert guest.microvm.mem == 16384 && guest.microvm.vcpu == 8;
assert stateVolume != null && stateVolume.size == 131072;
assert cacheVolume != null && cacheVolume.size == 131072;
assert mediaShare != null && mediaShare.proto == "virtiofs" && mediaShare.readOnly;
assert importShare != null && importShare.readOnly;
assert host.sys.virtualisation.microvm.instances.jellyfin.enable;
assert stagedHost.sys.services.jellyfin.enable && stagedHost.sys.services.plex.enable;
assert !stagedGuest.services.jellyfin.enable;
assert stagedGuest.microvm.devices == [ ];
assert hasImportSudo stagedGuest;
assert hasImportProgram stagedGuest;
assert !(hasImportSudo readyGuest);
assert !(hasImportProgram readyGuest);
assert !builtins.hasAttr "jellyfin-vps-relay" stagedHost.systemd.sockets;
assert !builtins.hasAttr "jellyfin-vps-relay" stagedWithVps.systemd.sockets;
assert !(lib.elem 8096 stagedWithVps.networking.firewall.interfaces.tailscale0.allowedTCPPorts);
assert !(lib.hasInfix "-s 100.99.88.77/32" stagedWithVps.networking.firewall.extraCommands);
assert !readyHost.sys.services.jellyfin.enable && readyGuest.services.jellyfin.enable;
assert builtins.isString readyHost.system.build.toplevel.drvPath;
assert builtins.isString readyGuest.system.build.toplevel.drvPath;
assert !(lib.any (share: share.mountPoint == "/mnt/host-jellyfin") readyGuest.microvm.shares);
assert readyHost.systemd.sockets.jellyfin-vps-relay.listenStreams == [ "100.85.254.99:8096" ];
assert readyHost.systemd.sockets.jellyfin-vps-relay.socketConfig.FreeBind;
assert !(readyHost.systemd.sockets.jellyfin-vps-relay.socketConfig ? BindToDevice);
assert lib.hasSuffix "10.100.0.72:8096"
  readyHost.systemd.services.jellyfin-vps-relay.serviceConfig.ExecStart;
assert lib.hasInfix "-s 100.99.88.77/32" readyHost.networking.firewall.extraCommands;
assert lib.elem "intel_iommu=on" gpuHost.boot.kernelParams;
assert
  map (device: { inherit (device) bus path; }) gpuGuest.microvm.devices == [
    {
      bus = "pci";
      path = "0000:03:00.0";
    }
    {
      bus = "pci";
      path = "0000:03:00.1";
    }
  ];
assert !(lib.elem 8096 host.networking.firewall.allowedTCPPorts);
assert !(lib.elem 8096 host.networking.firewall.interfaces.tailscale0.allowedTCPPorts);
assert host.sys.services.plex.enable;
assert !(lib.elem 8096 guest.networking.firewall.allowedTCPPorts);
assert lib.hasInfix "-i microvm0 -s 10.100.0.1/32 -p tcp --dport 8096 -j ACCEPT"
  guest.networking.firewall.extraCommands;
pkgs.runCommand "jellyfin-microvm-contract" { } "touch $out"
