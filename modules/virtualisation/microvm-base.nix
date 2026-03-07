{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sys.virtualisation.microvm;
  mkVmName = name: "${name}-vm";

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

  reverseProxyModule =
    { config, ... }:
    {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable Traefik reverse proxy configuration for this VM.";
        };

        subdomain = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Subdomain used for standard hostname-based routing.";
        };

        url = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Backend URL for the reverse proxy target.";
        };

        middlewares = lib.mkOption {
          type = lib.types.nullOr (lib.types.listOf lib.types.str);
          default = null;
          description = "Traefik middlewares applied to the generated router.";
        };

        entryPoints = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "web" ];
          description = "Traefik entry points applied to the generated router.";
        };
      };

      config.enable = lib.mkDefault (config.subdomain != null && config.url != null);
    };

  instanceModule =
    { name, config, ... }:
    {
      options = {
        enable = lib.mkEnableOption "MicroVM instance ${name}";

        autostart = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to autostart this VM on boot.";
        };

        flake = lib.mkOption {
          type = lib.types.nullOr lib.types.anything;
          default = null;
          description = "Flake to attach to the generated microvm.vms entry.";
        };

        vmConfig = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { };
          description = "Additional attributes merged into the generated microvm.vms entry.";
        };

        ip = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "IP address of the VM on the microvm bridge.";
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
          };
        };

        cfTunnel = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable Cloudflare Tunnel ingress for this VM.";
          };

          ingress = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { };
            description = "Cloudflare Tunnel ingress rules for this VM.";
          };
        };

        reverseProxy = lib.mkOption {
          type = lib.types.submodule reverseProxyModule;
          default = { };
          description = "Traefik reverse proxy configuration for this VM.";
        };
      };

      config = {
        autostart = lib.mkDefault config.enable;
        portForward.enable = lib.mkDefault (config.enable && config.portForward.ports != [ ]);
        cfTunnel.enable = lib.mkDefault (config.enable && config.cfTunnel.ingress != { });
      };
    };

  enabledInstances = lib.filterAttrs (_: instance: instance.enable) cfg.instances;

  derivedVms = builtins.listToAttrs (
    lib.mapAttrsToList (name: instance: {
      name = mkVmName name;
      value =
        instance.vmConfig // lib.optionalAttrs (instance.flake != null) { inherit (instance) flake; };
    }) enabledInstances
  );

  derivedAutostart = lib.mapAttrsToList (name: _: mkVmName name) (
    lib.filterAttrs (_: instance: instance.autostart) enabledInstances
  );

  derivedExpose = builtins.listToAttrs (
    lib.mapAttrsToList (name: instance: {
      name = mkVmName name;
      value = {
        inherit (instance) ip portForward cfTunnel;
      };
    }) enabledInstances
  );

  allVms = derivedVms // cfg.vms;

  allAutostart = lib.unique (derivedAutostart ++ cfg.autostart);

  allExpose = derivedExpose // cfg.expose;

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
  allForwardPorts = lib.flatten (lib.mapAttrsToList mkForwardPorts allExpose);

  # Collect all cfTunnel ingress rules
  allCfTunnelIngress = lib.mkMerge (
    lib.mapAttrsToList (
      _: vmCfg:
      lib.optionalAttrs (vmCfg.cfTunnel.enable && vmCfg.cfTunnel.ingress != { }) vmCfg.cfTunnel.ingress
    ) allExpose
  );

  exposedVmNames = builtins.attrNames allExpose;

  unknownExposeVms = lib.filter (name: !(lib.hasAttr name allVms)) exposedVmNames;

  unknownAutostartVms = lib.filter (name: !(lib.hasAttr name allVms)) allAutostart;

  enabledInstanceNames = builtins.attrNames enabledInstances;

  missingFlakeInstances = lib.filter (
    name: enabledInstances.${name}.flake == null
  ) enabledInstanceNames;

  missingIpPortForwardInstances = lib.filter (
    name:
    let
      instance = enabledInstances.${name};
    in
    instance.portForward.enable && instance.ip == null
  ) enabledInstanceNames;

  reverseProxyMissingFields = lib.filter (
    name:
    let
      instance = enabledInstances.${name};
    in
    instance.reverseProxy.enable
    && (instance.reverseProxy.subdomain == null || instance.reverseProxy.url == null)
  ) enabledInstanceNames;

  portForwardEnabledWithoutPorts = lib.filter (
    name:
    let
      vmCfg = allExpose.${name};
    in
    vmCfg.portForward.enable && vmCfg.portForward.ports == [ ]
  ) exposedVmNames;

  cfTunnelEnabledWithoutIngress = lib.filter (
    name:
    let
      vmCfg = allExpose.${name};
    in
    vmCfg.cfTunnel.enable && vmCfg.cfTunnel.ingress == { }
  ) exposedVmNames;

  cloudflaredEnabled = config.sys.services.cloudflared.enable or false;

  enabledCfTunnelVms = lib.filter (name: allExpose.${name}.cfTunnel.enable) exposedVmNames;

  duplicateForwardPortKeys =
    let
      keys = map (rule: "${rule.proto}:${toString rule.sourcePort}") allForwardPorts;
    in
    lib.unique (
      lib.filter (key: builtins.length (lib.filter (candidate: candidate == key) keys) > 1) keys
    );

  duplicateIngressHosts =
    let
      hosts = lib.flatten (
        lib.mapAttrsToList (
          _: vmCfg: lib.optionals vmCfg.cfTunnel.enable (builtins.attrNames vmCfg.cfTunnel.ingress)
        ) allExpose
      );
    in
    lib.unique (
      lib.filter (host: builtins.length (lib.filter (candidate: candidate == host) hosts) > 1) hosts
    );

  formatList = list: lib.concatStringsSep ", " list;
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

    instances = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule instanceModule);
      default = { };
      description = ''
        Logical per-VM host configuration.
        Use this namespace to opt a VM into a host and control related
        exposure toggles such as port forwarding, Cloudflare Tunnel, and
        reverse proxy generation.
      '';
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
    assertions = [
      {
        assertion = missingFlakeInstances == [ ];
        message = "sys.virtualisation.microvm.instances is missing flake for enabled VMs: ${formatList missingFlakeInstances}";
      }
      {
        assertion = missingIpPortForwardInstances == [ ];
        message = "sys.virtualisation.microvm.instances enables port forwarding without an IP for: ${formatList missingIpPortForwardInstances}";
      }
      {
        assertion = reverseProxyMissingFields == [ ];
        message = "sys.virtualisation.microvm.instances enables reverseProxy without both subdomain and url for: ${formatList reverseProxyMissingFields}";
      }
      {
        assertion = unknownExposeVms == [ ];
        message = "sys.virtualisation.microvm.expose contains unknown VMs: ${formatList unknownExposeVms}";
      }
      {
        assertion = unknownAutostartVms == [ ];
        message = "sys.virtualisation.microvm.autostart contains unknown VMs: ${formatList unknownAutostartVms}";
      }
      {
        assertion = portForwardEnabledWithoutPorts == [ ];
        message = "sys.virtualisation.microvm (expose/instances) enables port forwarding without ports for: ${formatList portForwardEnabledWithoutPorts}";
      }
      {
        assertion = cfTunnelEnabledWithoutIngress == [ ];
        message = "sys.virtualisation.microvm (expose/instances) enables Cloudflare Tunnel without ingress rules for: ${formatList cfTunnelEnabledWithoutIngress}";
      }
      {
        assertion = duplicateForwardPortKeys == [ ];
        message = "sys.virtualisation.microvm (expose/instances) defines duplicate forwarded source ports: ${formatList duplicateForwardPortKeys}";
      }
      {
        assertion = duplicateIngressHosts == [ ];
        message = "sys.virtualisation.microvm (expose/instances) defines duplicate Cloudflare ingress hosts: ${formatList duplicateIngressHosts}";
      }
      {
        assertion = cloudflaredEnabled || enabledCfTunnelVms == [ ];
        message = "sys.virtualisation.microvm (expose/instances) enables Cloudflare Tunnel for ${formatList enabledCfTunnelVms}, but sys.services.cloudflared.enable is false";
      }
    ];

    microvm = {
      autostart = allAutostart;
      vms = allVms;
      inherit (cfg) stateDir;
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
