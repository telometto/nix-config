# Boot real nested guests through the pinned upstream units. No private payloads.
{ pkgs, inputs }:
let
  inherit (pkgs) lib;
  mkGuest =
    generation:
    inputs.nixpkgs.lib.nixosSystem {
      system = pkgs.stdenv.hostPlatform.system;
      modules = [
        inputs.microvm.nixosModules.microvm
        {
          networking.hostName = "probe-vm";
          networking.firewall.enable = false;
          nix.enable = false;
          systemd.services."serial-getty@ttyS0".enable = false;
          system.stateVersion = "26.05";
          microvm = {
            hypervisor = "qemu";
            cpu = "qemu64";
            # Include software emulation without building unrelated CPU targets.
            qemu.package = pkgs.qemu_kvm;
            # Use the PC platform for guest devices and ACPI shutdown.
            qemu.machine = "q35";
            # Avoid nested KVM stalls on hosted CI; the outer test VM still uses KVM.
            # machineOpts replaces upstream defaults, so retain ACPI and memory merging.
            qemu.machineOpts = {
              accel = "tcg";
              acpi = "on";
              mem-merge = "on";
            };
            mem = 512;
            storeOnDisk = true;
            shares = [
              {
                source = "/var/lib/probe";
                mountPoint = "/probe";
                tag = "probe";
              }
            ];
          };
          environment.etc."generation".text = generation;
          systemd.services.report-generation = {
            wantedBy = [ "multi-user.target" ];
            # The first report permits a restart, so ACPI shutdown must be ready.
            wants = [ "systemd-logind.service" ];
            after = [
              "local-fs.target"
              "systemd-logind.service"
            ];
            serviceConfig.Restart = "always";
            path = [ pkgs.coreutils ];
            script = ''
              while true; do
                printf '%s %s %s\n' "$(cat /etc/generation)" \
                  "$(readlink -f /run/current-system)" \
                  "$(cat /proc/sys/kernel/random/boot_id)" > /probe/report.tmp
                mv /probe/report.tmp /probe/report
                sleep 1
              done
            '';
          };
        }
      ];
    };
  first = mkGuest "first";
  second = mkGuest "second";
  mkFlake = guest: {
    outPath = pkgs.writeTextDir "fixture" (toString guest.config.system.build.toplevel);
    nixosConfigurations.probe-vm = guest;
  };
  firstFlake = mkFlake first;
  secondFlake = mkFlake second;
  runner = guest: toString guest.config.microvm.declaredRunner;
  sourceA = "github:example/config?ref=first";
  sourceB = "git+file:///srv/config with spaces";
  reader = pkgs.writeText "flake-reader.py" ''
    import pathlib
    import sys

    state = pathlib.Path("/var/lib/microvms/probe-vm")
    allowed = {value + "\n" for value in sys.argv[1:]}
    count = 0
    while not pathlib.Path("/tmp/stop-reader").exists():
        value = (state / "flake").read_text()
        if value not in allowed:
            pathlib.Path("/tmp/reader-error").write_text(repr(value))
            raise SystemExit(1)
        count += 1
        if count == 1:
            pathlib.Path("/tmp/reader-ready").touch()
    pathlib.Path("/tmp/reader-count").write_text(str(count))
  '';
in
pkgs.testers.runNixOSTest {
  name = "microvm-lifecycle";
  nodes.machine = { config, ... }: {
    imports = [ inputs.microvm.nixosModules.host ];
    virtualisation.memorySize = 2048;
    environment.systemPackages = [ pkgs.python3 ];
    microvm = {
      host.enable = true;
      vms.probe-vm = {
        flake = firstFlake;
        updateFlake = sourceA;
        restartIfChanged = true;
      };
    };
    systemd.services = lib.mkMerge [
      (import ../lib/microvm-install-services.nix {
        inherit lib;
        inherit (config.microvm) stateDir vms;
      })
      {
        # Widen the rollback race: booted must wait for installation even when
        # switch-to-configuration queues the VM restart before the installer.
        "install-microvm-probe-vm".preStart = "sleep 2";
      }
    ];
    specialisation = {
      second.configuration.microvm.vms.probe-vm.flake = lib.mkForce secondFlake;
      reference.configuration.microvm.vms.probe-vm = {
        flake = lib.mkForce secondFlake;
        updateFlake = lib.mkForce sourceB;
      };
      immutable.configuration.microvm.vms.probe-vm = {
        flake = lib.mkForce secondFlake;
        updateFlake = lib.mkForce null;
      };
      no-restart.configuration.microvm.vms.probe-vm = {
        flake = lib.mkForce secondFlake;
        restartIfChanged = lib.mkForce false;
      };
    };
  };
  testScript = ''
    import shlex

    start_all()
    machine.wait_for_unit("microvm@probe-vm.service")
    base = machine.succeed("readlink -f /run/current-system").strip()
    state = "/var/lib/microvms/probe-vm"
    source_a = ${builtins.toJSON sourceA}
    source_b = ${builtins.toJSON sourceB}
    immutable = "${secondFlake.outPath}"

    def switch(name):
        machine.succeed(f"{base}/specialisation/{name}/bin/switch-to-configuration test", timeout=300)

    def report(generation, system):
        try:
            machine.wait_until_succeeds(
                f"test -f /var/lib/probe/report && grep -F -- {shlex.quote(generation + ' ' + system + ' ')} /var/lib/probe/report",
                timeout=300,
            )
        except Exception:
            print(machine.execute("systemctl status --no-pager --full microvm@probe-vm.service install-microvm-probe-vm.service")[1])
            print(machine.execute("journalctl -b --no-pager -n 200 -u microvm@probe-vm.service -u install-microvm-probe-vm.service")[1])
            raise
        return machine.succeed("cat /var/lib/probe/report").strip()

    def current(expected):
        assert machine.succeed(f"readlink -f {state}/current").strip() == expected

    def booted(expected):
        actual = machine.succeed(f"readlink -f {state}/booted").strip()
        assert actual == expected, f"booted runner: expected {expected}, got {actual}"

    def reference(expected):
        assert machine.succeed(f"cat {state}/flake") == expected + "\n"
        assert machine.succeed(f"stat -c '%U:%G:%a' {state}/flake").strip() == "microvm:kvm:644"

    with subtest("fresh installation boots the declared generation"):
        report("first", "${first.config.system.build.toplevel}")
        current("${runner first}")
        booted("${runner first}")
        reference(source_a)

    with subtest("existing VM advances runner and running configuration"):
        switch("second")
        current("${runner second}")
        report("second", "${second.config.system.build.toplevel}")
        booted("${runner second}")
        reference(source_a)

    with subtest("reference changes and null opt-out are atomic for concurrent readers"):
        args = " ".join(shlex.quote(s) for s in [source_a, source_b, immutable])
        machine.succeed(f"python3 ${reader} {args} >/tmp/reader-log 2>&1 &")
        machine.wait_for_file("/tmp/reader-ready")
        switch("reference")
        reference(source_b)
        # Reset the normal systemd rate limit for this artificial stress loop.
        machine.succeed("set -e; for i in $(seq 1 30); do systemctl reset-failed install-microvm-probe-vm.service; systemctl restart install-microvm-probe-vm.service; done")
        switch("immutable")
        reference(immutable)
        machine.succeed("touch /tmp/stop-reader")
        machine.wait_for_file("/tmp/reader-count")
        machine.fail("test -e /tmp/reader-error")
        assert int(machine.succeed("cat /tmp/reader-count")) > 0
        machine.succeed(f"test -z \"$(find {state} -name '.flake.*' -print)\"")
        report("second", "${second.config.system.build.toplevel}")

    with subtest("restart opt-out installs runner but retains running guest"):
        machine.succeed(f"{base}/bin/switch-to-configuration test", timeout=300)
        before = report("first", "${first.config.system.build.toplevel}")
        booted("${runner first}")
        pid = machine.succeed("systemctl show microvm@probe-vm.service -p MainPID --value")
        switch("no-restart")
        assert machine.succeed("systemctl show microvm@probe-vm.service -p MainPID --value") == pid
        booted("${runner first}")
        current("${runner second}")
        assert report("first", "${first.config.system.build.toplevel}") == before
        machine.succeed("systemctl restart microvm@probe-vm.service")
        report("second", "${second.config.system.build.toplevel}")
        booted("${runner second}")
        # Exercise the runner-selection/restart boundary used by microvm -Ru
        # without fetching a remote flake from the network-isolated test VM.
        machine.succeed(f"ln -sTf '${runner first}' {state}/current")
        machine.succeed("systemctl restart microvm@probe-vm.service")
        current("${runner first}")
        report("first", "${first.config.system.build.toplevel}")
        booted("${runner first}")
  '';
}
