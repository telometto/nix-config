{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sys.virtualisation.microvm;
  registry = import ../../vms/vm-registry.nix;
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

  publicationModule = {
    options = {
      enable = lib.mkEnableOption "public HTTP publication";

      hostname = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Hostname label under the canonical public domain.";
      };

      policy = lib.mkOption {
        type = lib.types.str;
        default = "strict";
        description = ''
          Registered publication compatibility policy whose middleware
          references must exist.
        '';
      };
    };
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

        publication = lib.mkOption {
          type = lib.types.submodule publicationModule;
          default = { };
          description = "Public HTTP publication for this VM.";
        };

        cfTunnel = lib.mkOption {
          type = lib.types.nullOr lib.types.attrs;
          default = null;
          visible = false;
          description = "Removed legacy Cloudflare Tunnel configuration.";
        };

        reverseProxy = lib.mkOption {
          type = lib.types.nullOr lib.types.attrs;
          default = null;
          visible = false;
          description = "Removed legacy Traefik reverse proxy configuration.";
        };
      };

      config = {
        autostart = lib.mkDefault config.enable;
        portForward.enable = lib.mkDefault (config.enable && config.portForward.ports != [ ]);
      };
    };

  enabledInstances = lib.filterAttrs (_: instance: instance.enable) cfg.instances;
  publicationPolicies = config.services.traefik.publicationPolicyMiddlewares // {
    strict = [ "security-headers" ];
  };
  strictPolicyOverridden = builtins.hasAttr "strict" config.services.traefik.publicationPolicyMiddlewares;
  requestedPublications = lib.filterAttrs (_: instance: instance.publication.enable) cfg.instances;
  requestedPublicationNames = builtins.attrNames requestedPublications;
  canonicalDomainLabels =
    if cfg.publication.canonicalDomain == null then
      [ ]
    else
      lib.splitString "." cfg.publication.canonicalDomain;
  canonicalDomainValid =
    cfg.publication.canonicalDomain == null
    || (
      builtins.stringLength cfg.publication.canonicalDomain <= 253
      && builtins.length canonicalDomainLabels >= 2
      && lib.all (
        label: builtins.match "^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$" label != null
      ) canonicalDomainLabels
    );
  publicationMissingHostnames = builtins.attrNames (
    lib.filterAttrs (_: instance: instance.publication.hostname == null) requestedPublications
  );
  publicationInvalidHostnames = builtins.attrNames (
    lib.filterAttrs (
      _: instance:
      instance.publication.hostname != null
      && builtins.match "^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$" instance.publication.hostname == null
    ) requestedPublications
  );
  publicationUnknownPolicies = builtins.attrNames (
    lib.filterAttrs (
      _: instance: !(builtins.hasAttr instance.publication.policy publicationPolicies)
    ) requestedPublications
  );
  requestedPublicationMiddlewares = lib.unique (
    lib.concatMap (
      instance:
      lib.optionals (builtins.hasAttr instance.publication.policy publicationPolicies)
        publicationPolicies.${instance.publication.policy}

    ) (builtins.attrValues requestedPublications)
    ++ lib.optional (requestedPublicationNames != [ ]) "crowdsec"
  );
  availableTraefikMiddlewares = lib.unique (
    lib.flatten (
      lib.mapAttrsToList (
        _: file: builtins.attrNames (file.settings.http.middlewares or { })
      ) config.services.traefik.dynamic.files
    )
  );
  publicationMissingMiddlewares = lib.filter (
    middleware: !(lib.elem middleware availableTraefikMiddlewares)
  ) requestedPublicationMiddlewares;
  publicationUnknownTargets = lib.filter (
    name: !(builtins.hasAttr name registry)
  ) requestedPublicationNames;
  enabledPublications = lib.filterAttrs (
    name: instance:
    instance.enable
    && instance.publication.hostname != null
    && builtins.hasAttr instance.publication.policy publicationPolicies
    && builtins.hasAttr name registry
    && cfg.publication.canonicalDomain != null
  ) requestedPublications;
  publicationHostnames = lib.mapAttrsToList (
    _: instance: "${instance.publication.hostname}.${cfg.publication.canonicalDomain}"
  ) enabledPublications;
  duplicatePublicationHostnames = duplicateValues publicationHostnames;
  publicationDisabledTargets = builtins.attrNames (
    lib.filterAttrs (_: instance: instance.publication.enable && !instance.enable) cfg.instances
  );
  instancesUsingRemovedCfTunnel = builtins.attrNames (
    lib.filterAttrs (_: instance: instance.cfTunnel != null) cfg.instances
  );
  instancesUsingRemovedReverseProxy = builtins.attrNames (
    lib.filterAttrs (_: instance: instance.reverseProxy != null) cfg.instances
  );

  publicationIngress = builtins.listToAttrs (
    lib.mapAttrsToList (_: instance: {
      name = "${instance.publication.hostname}.${cfg.publication.canonicalDomain}";
      value = "http://localhost:80";
    }) enabledPublications
  );

  publicationRouters = lib.mapAttrs (name: instance: {
    rule = "Host(`${instance.publication.hostname}.${cfg.publication.canonicalDomain}`)";
    service = name;
    entryPoints = [ "web" ];
    middlewares = publicationPolicies.${instance.publication.policy} ++ [ "crowdsec" ];
  }) enabledPublications;

  publicationServices = lib.mapAttrs (name: _: {
    loadBalancer.servers = [
      { url = "http://${registry.${name}.ip}:${toString registry.${name}.port}"; }
    ];
  }) enabledPublications;

  # Registry entries can opt into a dedicated host bridge. Only materialise
  # that topology when the matching VM instance is enabled on this host.
  isolatedRegistryEntries = lib.filterAttrs (
    name: entry: builtins.hasAttr name enabledInstances && entry ? hostBridge
  ) registry;

  isolatedBridgeNetdevs = lib.mapAttrs' (
    name: entry:
    lib.nameValuePair "10-${name}-bridge" {
      netdevConfig = {
        Kind = "bridge";
        Name = entry.hostBridge;
      };
    }
  ) isolatedRegistryEntries;

  isolatedBridgeNetworks = lib.mapAttrs' (
    name: entry:
    lib.nameValuePair "10-${name}-bridge" {
      matchConfig.Name = entry.hostBridge;
      networkConfig = {
        Address = [
          "${entry.gateway or (throw "Registry entry ${name} requires gateway when hostBridge is set")}/${
            toString (entry.prefixLength or 24)
          }"
        ];
        LinkLocalAddressing = "no";
      };
    }
  ) isolatedRegistryEntries;

  # Specific tap units sort before 12-microvm-tap, keeping isolated taps off
  # the shared bridge while retaining the shared vm-* default for other VMs.
  isolatedTapNetworks = lib.mapAttrs' (
    name: entry:
    lib.nameValuePair "11-${name}-tap" {
      matchConfig.Name = entry.tapId or "vm-${entry.name}";
      networkConfig.Bridge = entry.hostBridge;
    }
  ) isolatedRegistryEntries;

  isolatedBridgeNames = lib.unique (
    lib.mapAttrsToList (_: entry: entry.hostBridge) isolatedRegistryEntries
  );

  # The NixOS iptables firewall manages host INPUT, while NAT permits forwarding
  # from its internal interfaces. Keep dedicated VM networks routable to the
  # external interface without allowing any internal bridge to route to another.
  internalBridgeNames = [ "microvm-br0" ] ++ isolatedBridgeNames;
  mkBridgePairs =
    bridges:
    if bridges == [ ] then
      [ ]
    else
      let
        source = builtins.head bridges;
        remaining = builtins.tail bridges;
      in
      map (destination: { inherit source destination; }) remaining ++ mkBridgePairs remaining;
  isolationBridgePairs = mkBridgePairs internalBridgeNames;
  isolationChain = "nixos-microvm-isolation";
  isolationForwardRules = lib.concatMapStringsSep "\n" (pair: ''
    ${pkgs.iptables}/bin/iptables -w -A ${isolationChain} -i ${lib.escapeShellArg pair.source} -o ${lib.escapeShellArg pair.destination} -j DROP
    ${pkgs.iptables}/bin/iptables -w -A ${isolationChain} -i ${lib.escapeShellArg pair.destination} -o ${lib.escapeShellArg pair.source} -j DROP
  '') isolationBridgePairs;
  isolationFirewallCleanupCommands = ''
    while ${pkgs.iptables}/bin/iptables -w -C FORWARD -j ${isolationChain} 2>/dev/null; do
      ${pkgs.iptables}/bin/iptables -w -D FORWARD -j ${isolationChain}
    done
    ${pkgs.iptables}/bin/iptables -w -F ${isolationChain} 2>/dev/null || true
    ${pkgs.iptables}/bin/iptables -w -X ${isolationChain} 2>/dev/null || true
  '';
  isolationFirewallCommands =
    isolationFirewallCleanupCommands
    + lib.optionalString (isolationBridgePairs != [ ]) ''
      ${pkgs.iptables}/bin/iptables -w -N ${isolationChain} 2>/dev/null || true
      ${pkgs.iptables}/bin/iptables -w -F ${isolationChain}
      ${isolationForwardRules}
      ${pkgs.iptables}/bin/iptables -w -C FORWARD -j ${isolationChain} 2>/dev/null || \
        ${pkgs.iptables}/bin/iptables -w -I FORWARD 1 -j ${isolationChain}
    '';

  isolatedFirewallInterfaces = builtins.listToAttrs (
    map (bridge: {
      name = bridge;
      value = {
        allowedTCPPorts = [ ];
        allowedUDPPorts = [ ];
      };
    }) isolatedBridgeNames
  );

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

  # Generate NAT forwardPorts from enabled VM instances.
  mkForwardPorts =
    _: vmCfg:
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

  allForwardPorts = lib.flatten (lib.mapAttrsToList mkForwardPorts enabledInstances);

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

  portForwardEnabledWithoutPorts = lib.filter (
    name:
    let
      vmCfg = enabledInstances.${name};
    in
    vmCfg.portForward.enable && vmCfg.portForward.ports == [ ]
  ) enabledInstanceNames;

  cloudflaredEnabled = config.sys.services.cloudflared.enable or false;
  traefikEnabled = config.services.traefik.enable or false;

  duplicateForwardPortKeys =
    let
      keys = map (rule: "${rule.proto}:${toString rule.sourcePort}") allForwardPorts;
    in
    lib.unique (
      lib.filter (key: builtins.length (lib.filter (candidate: candidate == key) keys) > 1) keys
    );

  duplicateValues =
    values:
    lib.unique (
      lib.filter (value: builtins.length (lib.filter (candidate: candidate == value) values) > 1) values
    );

  formatList = list: lib.concatStringsSep ", " list;
in
{
  imports = [
    (lib.mkRemovedOptionModule [ "sys" "virtualisation" "microvm" "hypervisor" ] ''
      The host-wide hypervisor option was not applied to generated instances.
      Configure the hypervisor in each guest configuration when required.
    '')
    (lib.mkRemovedOptionModule [ "sys" "virtualisation" "microvm" "autostart" ] ''
      Use sys.virtualisation.microvm.instances.<name>.autostart instead.
    '')
    (lib.mkRemovedOptionModule [ "sys" "virtualisation" "microvm" "vms" ] ''
      Use sys.virtualisation.microvm.instances.<name>.flake and vmConfig instead.
    '')
    (lib.mkRemovedOptionModule [ "sys" "virtualisation" "microvm" "expose" ] ''
      Use sys.virtualisation.microvm.instances.<name>.portForward and
      sys.virtualisation.microvm.instances.<name>.publication instead.
    '')
  ];

  options.sys.virtualisation.microvm = {
    enable = lib.mkEnableOption "microvm.nix host for running lightweight VMs";

    instances = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule instanceModule);
      default = { };
      description = ''
        Logical per-VM host configuration. Use this namespace to opt a VM into
        a host and control instance-local port forwarding and public HTTP
        publication.
      '';
    };

    publication = {
      canonicalDomain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Lowercase DNS domain used by public HTTP publications.";
      };

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
        assertion = portForwardEnabledWithoutPorts == [ ];
        message = "sys.virtualisation.microvm.instances enables port forwarding without ports for: ${formatList portForwardEnabledWithoutPorts}";
      }
      {
        assertion = duplicateForwardPortKeys == [ ];
        message = "sys.virtualisation.microvm.instances defines duplicate forwarded source ports: ${formatList duplicateForwardPortKeys}";
      }
      {
        assertion = publicationDisabledTargets == [ ];
        message = "sys.virtualisation.microvm.instances enables publication for disabled VMs: ${formatList publicationDisabledTargets}";
      }
      {
        assertion = requestedPublicationNames == [ ] || cfg.publication.canonicalDomain != null;
        message = "sys.virtualisation.microvm.publication.canonicalDomain must be set when publications are enabled";
      }
      {
        assertion = canonicalDomainValid;
        message = "sys.virtualisation.microvm.publication.canonicalDomain must be a lowercase DNS domain with at least two valid labels";
      }
      {
        assertion = publicationMissingHostnames == [ ];
        message = "sys.virtualisation.microvm.instances enables publication without a hostname for: ${formatList publicationMissingHostnames}";
      }
      {
        assertion = publicationInvalidHostnames == [ ];
        message = "sys.virtualisation.microvm.instances uses invalid publication hostname labels for: ${formatList publicationInvalidHostnames}";
      }
      {
        assertion = publicationUnknownPolicies == [ ];
        message = "sys.virtualisation.microvm.instances selects unknown publication policies for: ${formatList publicationUnknownPolicies}";
      }
      {
        assertion = publicationMissingMiddlewares == [ ];
        message = "sys.virtualisation.microvm.instances selects publication middleware that is not defined in services.traefik.dynamic.files: ${formatList publicationMissingMiddlewares}";
      }
      {
        assertion = !strictPolicyOverridden;
        message = "services.traefik.publicationPolicyMiddlewares cannot redefine the built-in strict policy";
      }
      {
        assertion = publicationUnknownTargets == [ ];
        message = "sys.virtualisation.microvm.instances enables publication without a registry target for: ${formatList publicationUnknownTargets}";
      }
      {
        assertion = cloudflaredEnabled || requestedPublicationNames == [ ];
        message = "sys.virtualisation.microvm.instances enables publication for ${formatList requestedPublicationNames}, but sys.services.cloudflared.enable is false";
      }
      {
        assertion = traefikEnabled || requestedPublicationNames == [ ];
        message = "sys.virtualisation.microvm.instances enables publication for ${formatList requestedPublicationNames}, but services.traefik.enable is false";
      }
      {
        assertion = duplicatePublicationHostnames == [ ];
        message = "sys.virtualisation.microvm.instances defines duplicate publication hostnames: ${formatList duplicatePublicationHostnames}";
      }
      {
        assertion = instancesUsingRemovedCfTunnel == [ ];
        message = "sys.virtualisation.microvm.instances uses the removed cfTunnel option for: ${formatList instancesUsingRemovedCfTunnel}. Use publication or a bespoke host-level Cloudflare Tunnel ingress instead";
      }
      {
        assertion = instancesUsingRemovedReverseProxy == [ ];
        message = "sys.virtualisation.microvm.instances uses the removed reverseProxy option for: ${formatList instancesUsingRemovedReverseProxy}. Use publication or a bespoke host-level Traefik route instead";
      }
    ];

    microvm = {
      autostart = derivedAutostart;
      vms = derivedVms;
      inherit (cfg) stateDir;
    };

    # Bridges for MicroVM traffic (systemd-networkd style)
    systemd.network = {
      netdevs = {
        "10-microvm-br0".netdevConfig = {
          Kind = "bridge";
          Name = "microvm-br0";
        };
      }
      // isolatedBridgeNetdevs;

      networks = {
        "10-microvm-br0" = {
          matchConfig.Name = "microvm-br0";
          networkConfig.Address = [ "10.100.0.1/24" ];
          # Disable link-local to avoid extra addresses
          networkConfig.LinkLocalAddressing = "no";
        };

        # Attach every non-isolated VM tap interface (vm-*) to the shared bridge.
        "12-microvm-tap" = {
          matchConfig.Name = "vm-*";
          networkConfig.Bridge = "microvm-br0";
        };
      }
      // isolatedBridgeNetworks
      // isolatedTapNetworks;
    };

    networking = {
      useNetworkd = true;

      # NAT for MicroVM internet access
      nat = {
        enable = true;
        enableIPv6 = false;
        internalInterfaces = [ "microvm-br0" ] ++ isolatedBridgeNames;
        inherit (cfg) externalInterface;
        forwardPorts = allForwardPorts;
      };

      # VMs reach the internet via NAT (FORWARD chain) and use external DNS,
      # so neither bridge needs INPUT-chain trust on the host.
      # Add interfaces."microvm-br0".allowedTCPPorts here if a VM must reach
      # a specific host service directly.
      firewall = {
        interfaces = {
          "microvm-br0" = {
            allowedTCPPorts = [ ];
            allowedUDPPorts = [ ];
          };
        }
        // isolatedFirewallInterfaces;

        # Rebuild a private chain on every firewall start/reload so topology
        # changes cannot leave stale cross-bridge rules behind.
        extraCommands = isolationFirewallCommands;
        extraStopCommands = isolationFirewallCleanupCommands;
      };
    };

    sys.services.cloudflared.ingress = lib.mkIf (config.sys.services.cloudflared.enable or false
    ) publicationIngress;

    services.traefik.dynamic.files.microvm-publications.settings.http = {
      routers = publicationRouters;
      services = publicationServices;
    };
  };
}
