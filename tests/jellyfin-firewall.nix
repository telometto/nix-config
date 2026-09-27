{ pkgs }:
let
  inherit (pkgs) lib;
  firewall = vpsIPv4: import ../lib/jellyfin-vps-firewall.nix { inherit lib vpsIPv4; };
  current = firewall "100.116.146.113";
  next = firewall "100.99.88.77";
  disabled = firewall null;
  media = import ../hosts/blizzard/services/media.nix {
    inherit lib;
    VARS = { };
    config = { };
    consts = import ../lib/constants.nix;
    jellyfinSettings = import ../vms/jellyfin-settings.nix;
    inherit pkgs;
  };
  script = name: contents: pkgs.writeText name contents;
in
assert media.sys.services.jellyfin.enable;
assert media.networking.firewall.interfaces.tailscale0.allowedTCPPorts == [ ];
assert media.networking.firewall.extraCommands == disabled.extraCommands;
assert media.networking.firewall.extraStopCommands == disabled.extraStopCommands;
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
      ${script "jellyfin-disabled-start" disabled.extraCommands}
    touch "$out"
  ''
