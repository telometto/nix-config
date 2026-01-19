{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sys.virtualisation.microvm;

  # Port forward submodule
  portForwardModule = lib.types.submodule {
    options = {
      proto = lib.mkOption {
        type = lib.types.enum [
          "tcp"
          "udp"
          "both"
        ];
        default = "tcp";
        description = "Protocol for the port forward.";
      };
      sourcePort = lib.mkOption {
        type = lib.types.port;
        description = "Port on the host to listen on.";
      };
      destPort = lib.mkOption {
        type = lib.types.nullOr lib.types.port;
        default = null;
        description = "Port on the VM. Defaults to sourcePort if null.";
      };
    };
  };

  # VM exposure submodule (for cfTunnel and portForward per-VM)
  vmExposeModule = lib.types.submodule {
    options = {
      ip = lib.mkOption {
        type = lib.types.str;
        description = "IP address of the VM on the microvm bridge (e.g., 10.100.0.10).";
      };

      portForward = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable port forwarding from host to this VM.";
        };
        ports = lib.mkOption {
          type = lib.types.listOf portForwardModule;
          default = [ ];
          description = "List of ports to forward from host to VM.";
          example = [
            {
              proto = "both";
              sourcePort = 53;
            }
            {
              proto = "tcp";
              sourcePort = 3000;
            }
          ];
        };
      };

      cfTunnel = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Enable Cloudflare Tunnel ingress for this VM's services.
            Requires sys.services.cloudflared to be configured on the host.
          '';
        };
        ingress = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "Cloudflare Tunnel ingress rules for this VM.";
          example = {
            "adguard.example.com" = "http://10.100.0.10:80";
            "dns.example.com" = "tcp://10.100.0.10:53";
          };
        };
      };
    };
  };

  # Generate NAT forwardPorts from VM expose configs
  mkForwardPorts =
    vmName: vmCfg:
    lib.optionals vmCfg.portForward.enable (
      lib.flatten (
        map (
          p:
          let
            dest = "${vmCfg.ip}:${toString (if p.destPort != null then p.destPort else p.sourcePort)}";
            mkRule = proto: {
              inherit proto;
              inherit (p) sourcePort;
              destination = dest;
            };
          in
          if p.proto == "both" then
            [
              (mkRule "tcp")
              (mkRule "udp")
            ]
          else
            [ (mkRule p.proto) ]
        ) vmCfg.portForward.ports
      )
    );

  # Collect all forward ports from all VMs
  allForwardPorts = lib.flatten (lib.mapAttrsToList mkForwardPorts cfg.expose);

  # Collect all cfTunnel ingress rules
  allCfTunnelIngress = lib.mkMerge (
    lib.mapAttrsToList (
      _: vmCfg:
      lib.optionalAttrs (vmCfg.cfTunnel.enable && vmCfg.cfTunnel.ingress != { }) vmCfg.cfTunnel.ingress
    ) cfg.expose
  );
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

    expose = lib.mkOption {
      type = lib.types.attrsOf vmExposeModule;
      default = { };
      description = ''
        Per-VM exposure configuration for port forwarding and Cloudflare Tunnel.
        Keys are VM names (for documentation), values configure how to expose the VM.
      '';
      example = {
        adguard-vm = {
          ip = "10.100.0.10";
          portForward = {
            enable = true;
            ports = [
              {
                proto = "both";
                sourcePort = 53;
              }
              {
                proto = "tcp";
                sourcePort = 3000;
              }
            ];
          };
          cfTunnel = {
            enable = true;
            ingress = {
              "adguard.example.com" = "http://10.100.0.10:80";
            };
          };
        };
      };
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
        forwardPorts = allForwardPorts;
      };

      # Firewall trusts the MicroVM bridge
      firewall.trustedInterfaces = [ "microvm-br0" ];
    };

    # Add VM services to Cloudflare Tunnel ingress
    sys.services.cloudflared.ingress = lib.mkIf (config.sys.services.cloudflared.enable or false
    ) allCfTunnelIngress;
  };
}
