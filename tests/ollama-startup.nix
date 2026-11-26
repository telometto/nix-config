# Exercise the real rootless user unit with a local image, without Tailscale
# credentials, Ollama model downloads, or production networking.
{
  pkgs,
  hmStable,
  quadlet,
}:
let
  address = "100.64.0.2";
  lanAddress = "192.0.2.20";
  image = pkgs.dockerTools.buildImage {
    name = "ollama-startup";
    tag = "test";
    copyToRoot = pkgs.runCommand "ollama-startup-response" { } ''
      mkdir -p "$out/www"
      echo ollama-startup-ready > "$out/www/index.html"
    '';
    config.Cmd = [
      "${pkgs.busybox}/bin/httpd"
      "-f"
      "-p"
      "11434"
      "-h"
      "/www"
    ];
  };
in
pkgs.testers.runNixOSTest {
  name = "ollama-startup";
  nodes.machine = {
    imports = [ hmStable.nixosModules.home-manager ];
    virtualisation.podman.enable = true;
    # The rootless Quadlet helper observes the system network-online target.
    systemd.targets.network-online.wantedBy = [ "multi-user.target" ];
    users.users.fixture = {
      isNormalUser = true;
      uid = 1000;
      linger = true;
      autoSubUidGidRange = true;
    };
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      users.fixture =
        { lib, ... }:
        {
          imports = [
            quadlet.homeManagerModules.quadlet
            ../containers/ollama.nix
          ];
          home.stateVersion = "26.05";
          services.ollama-container = {
            enable = true;
            image = "localhost/ollama-startup:test";
            dataDir = "/home/fixture/models";
            listenAddresses = [
              "127.0.0.1"
              address
            ];
          };
          # Load the local image before the test starts the generated user unit.
          virtualisation.quadlet.containers.ollama-standalone.autoStart = lib.mkForce false;
        };
    };
  };
  testScript = ''
    import shlex

    def user(command):
        return "runuser -u fixture -- env XDG_RUNTIME_DIR=/run/user/1000 sh -c " + shlex.quote(command)

    def api(address):
        return f"curl --noproxy '*' --fail --connect-timeout 2 --max-time 5 http://{address}:11434/ | grep -Fx ollama-startup-ready"

    start_all()
    machine.wait_for_unit("home-manager-fixture.service")
    machine.wait_for_unit("user@1000.service")
    machine.succeed(user("podman load --input ${image}"))
    machine.fail("ip link show tailscale0")
    machine.succeed(user("systemctl --user start ollama-standalone.service"))
    machine.wait_until_succeeds(api("127.0.0.1"))
    container = machine.succeed(user("podman inspect --format '{{.Id}}' ollama-standalone")).strip()

    # Keep the address absent longer than systemd's default start-limit window.
    machine.sleep(12)
    machine.succeed(user("systemctl --user is-active ollama-standalone.service"))
    machine.succeed(user("test $(systemctl --user show -p NRestarts --value ollama-standalone.service) = 0"))
    machine.succeed("ip link add tailscale0 type dummy; ip addr add ${address}/32 dev tailscale0; ip link set tailscale0 up")
    machine.wait_until_succeeds(api("${address}"))

    # Freebind must never widen publication to another local interface.
    machine.succeed("ip link add lan0 type dummy; ip addr add ${lanAddress}/32 dev lan0; ip link set lan0 up")
    machine.fail("curl --noproxy '*' --fail --connect-timeout 2 --max-time 3 http://${lanAddress}:11434/")

    # Address loss/reassignment must recover without restarting the container.
    machine.succeed("ip addr del ${address}/32 dev tailscale0")
    machine.succeed(api("127.0.0.1"))
    machine.succeed("ip addr add ${address}/32 dev tailscale0")
    machine.wait_until_succeeds(api("${address}"))
    assert machine.succeed(user("podman inspect --format '{{.Id}}' ollama-standalone")).strip() == container
    machine.succeed(user("test $(systemctl --user show -p NRestarts --value ollama-standalone.service) = 0"))
  '';
}
