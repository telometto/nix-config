{ seerrVm, pkgs }:
let
  inherit (pkgs) lib;
  guest = seerrVm.config;
  unit = guest.systemd.services.seerr;
  stateVolume = lib.findFirst (
    volume: volume.mountPoint == guest.services.seerr.configDir
  ) null guest.microvm.volumes;
in
# Seerr must read the existing Overseerr disk, rather than initialize an empty
# directory under the upstream module's stateVersion-dependent default path.
assert guest.services.seerr.enable;
assert !(guest.systemd.services ? overseerr);
assert stateVolume != null;
assert stateVolume.image == "overseerr-state.img" && stateVolume.size == 10240;
assert unit.environment.CONFIG_DIRECTORY == "/var/lib/overseerr";
assert unit.environment.PORT == "11040";
assert unit.serviceConfig.StateDirectory == "overseerr";
# DynamicUser would relocate state under /var/lib/private and conflict with
# the VM's mount point. A static user lets systemd take ownership of old data.
assert !unit.serviceConfig.DynamicUser;
assert unit.serviceConfig.User == "seerr" && unit.serviceConfig.Group == "seerr";
assert guest.users.users.seerr.isSystemUser && guest.users.users.seerr.group == "seerr";
assert unit.serviceConfig.StateDirectoryMode == "0700";
assert lib.elem "/var/lib/overseerr" unit.unitConfig.RequiresMountsFor;
assert lib.elem 11040 guest.networking.firewall.allowedTCPPorts;
# Keeping the runner name and tap avoids replacing the host's VM state folder.
assert guest.networking.hostName == "overseerr-vm";
assert guest.microvm.vsock.cid == 114;
assert lib.any (
  interface: interface.id == "vm-overseerr" && interface.mac == "02:00:00:00:00:0F"
) guest.microvm.interfaces;
pkgs.runCommand "seerr-state-tests" { } "touch $out"
