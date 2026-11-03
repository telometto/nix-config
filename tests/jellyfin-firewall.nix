{ pkgs }:
let
  inherit (pkgs) lib;
  firewall =
    vpsIPv4:
    import ../lib/jellyfin-vps-firewall.nix {
      inherit lib vpsIPv4;
      guestIPv4 = "10.100.0.72";
    };
  current = firewall "100.116.146.113";
  next = firewall "100.99.88.77";
  disabled = firewall null;
  media = import ../hosts/blizzard/services/media.nix {
    inherit lib;
    VARS = { };
    config = { };
    consts = import ../lib/constants.nix;
    jellyfinSettings = {
      vmServiceReady = false;
      vpsIPv4 = null;
    };
    inherit pkgs;
  };
  guestConfig =
    settings:
    import ../vms/jellyfin.nix {
      inherit lib pkgs;
      consts = import ../lib/constants.nix;
      jellyfinSettings = {
        gpuPassthrough = {
          enable = false;
          pciFunctions = [ ];
        };
      }
      // settings;
    };
  guestFirewall = settings: (guestConfig settings).networking.firewall.extraCommands;
  acceptsLanSubnet =
    subnet:
    lib.all (check: check.assertion)
      (guestConfig {
        vmServiceReady = true;
        lanIPv4Subnet = subnet;
      }).assertions;
  guestLan = guestFirewall {
    vmServiceReady = true;
    lanIPv4Subnet = "192.168.2.0/24";
  };
  guestPrivate = guestFirewall {
    vmServiceReady = true;
    lanIPv4Subnet = null;
  };
  guestStaged = guestFirewall {
    vmServiceReady = false;
    lanIPv4Subnet = "192.168.2.0/24";
  };
  script = name: contents: pkgs.writeText name contents;
in
assert media.sys.services.jellyfin.enable;
assert media.networking.firewall.interfaces.tailscale0.allowedTCPPorts == [ ];
assert media.networking.firewall.extraCommands == disabled.extraCommands;
assert media.networking.firewall.extraStopCommands == disabled.extraStopCommands;
assert lib.all acceptsLanSubnet [
  null
  "192.168.2.0/24"
  "0.0.0.0/0"
  "255.255.255.255/32"
];
assert lib.all (subnet: !acceptsLanSubnet subnet) [
  ""
  24
  "192.168.2.0"
  "256.168.2.0/24"
  "192.168.2.0/33"
  "192.168.2.0/-1"
  "192.168.2.0/24; true"
  "192.168.2.0/24\ntrue"
  "fd00::/64"
];
pkgs.runCommand "jellyfin-firewall-tests"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.bash
    ];
  }
  ''
    python3 ${./jellyfin-firewall-test.py} \
      ${script "jellyfin-current-start" current.extraCommands} \
      ${script "jellyfin-current-stop" current.extraStopCommands} \
      ${script "jellyfin-next-start" next.extraCommands} \
      ${script "jellyfin-disabled-start" disabled.extraCommands} \
      ${script "jellyfin-guest-lan" guestLan} \
      ${script "jellyfin-guest-private" guestPrivate} \
      ${script "jellyfin-guest-staged" guestStaged}
    touch "$out"
  ''
