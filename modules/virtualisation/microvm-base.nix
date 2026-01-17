{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sys.virtualisation.microvm;
in
{
  options.sys.virtualisation.microvm = {
    enable = lib.mkEnableOption "microvm.nix host for running lightweight VMs";

    hypervisor = lib.mkOption {
      type = lib.types.enum [
        "qemu"
        "cloud-hypervisor"
        "firecracker"
        "crosvm"
        "kvmtool"
      ];
      default = "cloud-hypervisor";
      description = ''
        Default hypervisor for MicroVMs.
        - cloud-hypervisor: Good security/features balance (Rust-based)
        - firecracker: Minimal attack surface, used by AWS Lambda
        - qemu: Most features but larger attack surface
      '';
    };

    autostart = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of MicroVM names to automatically start on boot.";
    };

    vms = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "MicroVM definitions to be merged into microvm.vms.";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/microvms";
      description = ''
        Base directory for MicroVM state (volumes, sockets, etc.).
        Each VM gets a subdirectory: <stateDir>/<vm-name>/
        Set to your ZFS dataset path for better snapshotting.
      '';
    };

    externalInterface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        External network interface for NAT. If null, NAT will use
        whatever default route is available (works for most setups).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    microvm = {
      inherit (cfg) autostart vms stateDir;
    };

    # Bridge for MicroVM traffic (systemd-networkd style)
    systemd.network = {
      netdevs."10-microvm-br0".netdevConfig = {
        Kind = "bridge";
        Name = "microvm-br0";
      };

      networks."10-microvm-br0" = {
        matchConfig.Name = "microvm-br0";
        networkConfig.Address = [ "10.100.0.1/24" ];
        # Disable link-local to avoid extra addresses
        networkConfig.LinkLocalAddressing = "no";
      };

      # Attach VM tap interfaces (vm-*) to the bridge
      networks."11-microvm-tap" = {
        matchConfig.Name = "vm-*";
        networkConfig.Bridge = "microvm-br0";
      };
    };

    networking = {
      useNetworkd = true;

      # NAT for MicroVM internet access
      nat = {
        enable = true;
        enableIPv6 = false;
        internalInterfaces = [ "microvm-br0" ];
        inherit (cfg) externalInterface;
      };

      # Firewall trusts the MicroVM bridge
      firewall.trustedInterfaces = [ "microvm-br0" ];
    };
  };
}
