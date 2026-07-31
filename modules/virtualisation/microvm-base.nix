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

  allowedPeerModule = {
    options = {
      primaryService = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Allow the source VM to initiate TCP connections to the target VM's registry service port.";
      };

      tcpPorts = lib.mkOption {
        type = lib.types.listOf lib.types.port;
        default = [ ];
        description = "Additional target TCP ports the source VM may initiate connections to.";
      };

      udpPorts = lib.mkOption {
        type = lib.types.listOf lib.types.port;
        default = [ ];
        description = "Target UDP ports the source VM may initiate flows to.";
      };

      reason = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Non-empty operational reason for this lateral network permission.";
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

        networkPolicy.allowedPeers = lib.mkOption {
          type = lib.types.attrsOf (lib.types.submodule allowedPeerModule);
          default = { };
          description = ''
            Host-local, directional service permissions keyed by logical target
            VM name. Replies are statefully allowed; new reverse connections
            require their own declaration.
          '';
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

  enabledInstanceNames = builtins.attrNames enabledInstances;
  registeredEnabledInstanceNames = lib.filter (
    name: builtins.hasAttr name registry
  ) enabledInstanceNames;
  unregisteredEnabledInstances = lib.filter (
    name: !(builtins.hasAttr name registry)
  ) enabledInstanceNames;
  registryIpMismatches = lib.filter (
    name: enabledInstances.${name}.ip != registry.${name}.ip
  ) registeredEnabledInstanceNames;
  registryNames = builtins.attrNames registry;

  identityFor =
    name:
    let
      entry = registry.${name};
    in
    {
      inherit name;
      inherit (entry) ip mac;
      tap = entry.tapId or "vm-${entry.name}";
      bridge = entry.hostBridge or "microvm-br0";
    };

  policyIdentities = map identityFor registeredEnabledInstanceNames;
  invalidPolicyTapNames = map (identity: identity.name) (
    lib.filter (
      identity: builtins.match "^vm-.+" identity.tap == null || builtins.stringLength identity.tap > 15
    ) policyIdentities
  );

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
      neighbors = [
        {
          Address = entry.ip;
          LinkLayerAddress = entry.mac;
        }
      ];
    }
  ) isolatedRegistryEntries;

  # Every enabled tap has unknown unicast/multicast flooding disabled. The
  # fallback vm-* unit remains fail-closed for an unexpected tap while still
  # attaching it to the bridge so the bridge-family policy can reject and
  # account for its frames.
  registeredTapNetworks = builtins.listToAttrs (
    map (
      identity:
      lib.nameValuePair "11-${identity.name}-tap" {
        matchConfig.Name = identity.tap;
        networkConfig.Bridge = identity.bridge;
        bridgeConfig = {
          Learning = true;
          Locked = false;
          MulticastFlood = false;
          UnicastFlood = false;
        };
      }
    ) policyIdentities
  );

  isolatedBridgeNames = lib.unique (
    lib.mapAttrsToList (_: entry: entry.hostBridge) isolatedRegistryEntries
  );

  internalBridgeNames = [ "microvm-br0" ] ++ isolatedBridgeNames;

  sharedBridgeNeighbors = map (identity: {
    Address = identity.ip;
    LinkLayerAddress = identity.mac;
  }) (lib.filter (identity: identity.bridge == "microvm-br0") policyIdentities);

  declaredEdges = lib.concatMap (
    sourceName:
    lib.mapAttrsToList (targetName: edge: {
      inherit
        sourceName
        targetName
        edge
        ;
    }) cfg.instances.${sourceName}.networkPolicy.allowedPeers
  ) (builtins.attrNames cfg.instances);

  edgeLabel = declaration: "${declaration.sourceName}->${declaration.targetName}";
  edgeSourceRegistered = declaration: builtins.hasAttr declaration.sourceName registry;
  edgeTargetRegistered = declaration: builtins.hasAttr declaration.targetName registry;
  edgeSourceEnabled = declaration: cfg.instances.${declaration.sourceName}.enable;
  edgeTargetEnabled =
    declaration:
    builtins.hasAttr declaration.targetName cfg.instances
    && cfg.instances.${declaration.targetName}.enable;
  edgeTouchesDedicatedBridge =
    declaration:
    edgeSourceRegistered declaration
    && edgeTargetRegistered declaration
    && (
      registry.${declaration.sourceName} ? hostBridge || registry.${declaration.targetName} ? hostBridge
    );
  hasDuplicates = values: builtins.length values != builtins.length (lib.unique values);

  policyUnknownSources = map edgeLabel (
    lib.filter (declaration: !(edgeSourceRegistered declaration)) declaredEdges
  );
  policyUnknownTargets = map edgeLabel (
    lib.filter (declaration: !(edgeTargetRegistered declaration)) declaredEdges
  );
  policyMissingTargetInstances = map edgeLabel (
    lib.filter (declaration: !(builtins.hasAttr declaration.targetName cfg.instances)) declaredEdges
  );
  policyDisabledSources = map edgeLabel (
    lib.filter (declaration: !(edgeSourceEnabled declaration)) declaredEdges
  );
  policyDisabledTargets = map edgeLabel (
    lib.filter (
      declaration:
      builtins.hasAttr declaration.targetName cfg.instances && !(edgeTargetEnabled declaration)
    ) declaredEdges
  );
  policySelfEdges = map edgeLabel (
    lib.filter (declaration: declaration.sourceName == declaration.targetName) declaredEdges
  );
  policyDedicatedEdges = map edgeLabel (lib.filter edgeTouchesDedicatedBridge declaredEdges);
  policyMissingReasons = map edgeLabel (
    lib.filter (declaration: lib.trim declaration.edge.reason == "") declaredEdges
  );
  policyEmptyServices = map edgeLabel (
    lib.filter (
      declaration:
      !declaration.edge.primaryService
      && declaration.edge.tcpPorts == [ ]
      && declaration.edge.udpPorts == [ ]
    ) declaredEdges
  );
  policyDuplicatePorts = map edgeLabel (
    lib.filter (
      declaration:
      hasDuplicates declaration.edge.tcpPorts
      || hasDuplicates declaration.edge.udpPorts
      || (
        declaration.edge.primaryService
        && edgeTargetRegistered declaration
        && lib.elem registry.${declaration.targetName}.port declaration.edge.tcpPorts
      )
    ) declaredEdges
  );

  validDeclaredEdges = lib.filter (
    declaration:
    edgeSourceRegistered declaration
    && edgeTargetRegistered declaration
    && edgeSourceEnabled declaration
    && edgeTargetEnabled declaration
    && declaration.sourceName != declaration.targetName
    && !(edgeTouchesDedicatedBridge declaration)
    && lib.trim declaration.edge.reason != ""
    && (
      declaration.edge.primaryService
      || declaration.edge.tcpPorts != [ ]
      || declaration.edge.udpPorts != [ ]
    )
  ) declaredEdges;

  serviceEdges = map (declaration: {
    source = identityFor declaration.sourceName;
    destination = identityFor declaration.targetName;
    tcpPorts = lib.unique (
      lib.optional declaration.edge.primaryService registry.${declaration.targetName}.port
      ++ declaration.edge.tcpPorts
    );
    udpPorts = lib.unique declaration.edge.udpPorts;
    inherit (declaration.edge) reason;
  }) validDeclaredEdges;

  registeredGatewayReferences = lib.concatMap (
    clientName:
    let
      gatewayAddress = registry.${clientName}.gateway or "10.100.0.1";
      gatewayName = lib.findFirst (
        candidateName: registry.${candidateName}.ip == gatewayAddress
      ) null registryNames;
    in
    lib.optional (gatewayName != null && gatewayName != clientName) {
      inherit clientName gatewayName;
    }
  ) registeredEnabledInstanceNames;

  disabledRegisteredGateways = map (reference: "${reference.clientName}->${reference.gatewayName}") (
    lib.filter (
      reference: !(builtins.hasAttr reference.gatewayName enabledInstances)
    ) registeredGatewayReferences
  );

  dedicatedRegisteredGateways = map (reference: "${reference.clientName}->${reference.gatewayName}") (
    lib.filter (
      reference:
      registry.${reference.clientName} ? hostBridge || registry.${reference.gatewayName} ? hostBridge
    ) registeredGatewayReferences
  );

  gatewayPairs =
    map
      (reference: {
        client = identityFor reference.clientName;
        gateway = identityFor reference.gatewayName;
      })
      (
        lib.filter (
          reference: builtins.hasAttr reference.gatewayName enabledInstances
        ) registeredGatewayReferences
      );

  policyCompiler = import ../../lib/microvm-network-policy.nix {
    inherit
      lib
      serviceEdges
      gatewayPairs
      internalBridgeNames
      ;
    identities = policyIdentities;
    inherit (cfg.networkPolicy) mode;
  };
  uncheckedPolicyRuleset = pkgs.writeText "microvm-network-policy-unchecked.nft" policyCompiler.ruleset;
  policyRuleset =
    pkgs.runCommand "microvm-network-policy.nft" { nativeBuildInputs = [ pkgs.nftables ]; }
      ''
        LD_PRELOAD="${pkgs.buildPackages.lklWithFirewall.lib}/lib/liblkl-hijack.so" \
          nft --check --file ${uncheckedPolicyRuleset}
        cp ${uncheckedPolicyRuleset} "$out"
      '';

  policyServiceName = "microvm-network-policy.service";
  installStaticFdb = pkgs.writeShellScript "install-microvm-static-fdb" ''
    set -eu

    tap_name="$1"
    bridge_name="$2"
    guest_mac="$3"

    for _ in {1..100}; do
      if ${pkgs.iproute2}/bin/bridge link show dev "$tap_name" | ${pkgs.gnugrep}/bin/grep -Fq "master $bridge_name"; then
        exec ${pkgs.iproute2}/bin/bridge fdb replace "$guest_mac" dev "$tap_name" master static
      fi
      ${pkgs.coreutils}/bin/sleep 0.05
    done

    echo "Timed out waiting for $tap_name to join $bridge_name" >&2
    exit 1
  '';
  policyVmUnitNames = map (name: "microvm@${mkVmName name}.service") enabledInstanceNames;
  policyTapUnitNames = map (
    name: "microvm-tap-interfaces@${mkVmName name}.service"
  ) enabledInstanceNames;
  policyUnitOverrides = builtins.listToAttrs (
    map (unitName: {
      name = lib.removeSuffix ".service" unitName;
      value = {
        requires = [ policyServiceName ];
        after = [ policyServiceName ];
      };
    }) policyVmUnitNames
    ++ map (identity: {
      name = "microvm-tap-interfaces@${mkVmName identity.name}";
      value = {
        requires = [ policyServiceName ];
        after = [ policyServiceName ];
        postStart = "${installStaticFdb} ${identity.tap} ${identity.bridge} ${identity.mac}";
      };
    }) policyIdentities
  );

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
        publication. Lateral permissions are declared under each instance's
        networkPolicy.allowedPeers attribute set.
      '';
    };

    publication = {
      canonicalDomain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Lowercase DNS domain used by public HTTP publications.";
      };

    };

    networkPolicy.mode = lib.mkOption {
      type = lib.types.enum [
        "audit"
        "enforce"
      ];
      default = "enforce";
      description = ''
        Whether undeclared traffic between enabled registered VM taps is logged
        and accepted temporarily, or logged and rejected. Identity validation,
        unknown taps, unsupported EtherTypes, multicast, and routed bypasses
        always remain enforced.
      '';
    };

    networkPolicy.renderedRuleset = lib.mkOption {
      type = lib.types.lines;
      readOnly = true;
      internal = true;
      description = "Rendered host-owned MicroVM nftables policy used by evaluation tests and the checked runtime artifact.";
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
    sys.virtualisation.microvm.networkPolicy.renderedRuleset = policyCompiler.ruleset;

    assertions = [
      {
        assertion = unregisteredEnabledInstances == [ ];
        message = "sys.virtualisation.microvm network policy requires registry entries for enabled VMs: ${formatList unregisteredEnabledInstances}";
      }
      {
        assertion = registryIpMismatches == [ ];
        message = "sys.virtualisation.microvm enabled instance IPs must match vm-registry.nix for: ${formatList registryIpMismatches}";
      }
      {
        assertion = invalidPolicyTapNames == [ ];
        message = "sys.virtualisation.microvm registry tap IDs must start with vm- and fit Linux's 15-character interface limit for: ${formatList invalidPolicyTapNames}";
      }
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
      {
        assertion = policyUnknownSources == [ ];
        message = "sys.virtualisation.microvm network policy has unregistered sources: ${formatList policyUnknownSources}";
      }
      {
        assertion = policyUnknownTargets == [ ];
        message = "sys.virtualisation.microvm network policy has unregistered targets: ${formatList policyUnknownTargets}";
      }
      {
        assertion = policyMissingTargetInstances == [ ];
        message = "sys.virtualisation.microvm network policy targets VMs not declared on this host: ${formatList policyMissingTargetInstances}";
      }
      {
        assertion = policyDisabledSources == [ ];
        message = "sys.virtualisation.microvm network policy declarations cannot have disabled sources: ${formatList policyDisabledSources}";
      }
      {
        assertion = policyDisabledTargets == [ ];
        message = "sys.virtualisation.microvm network policy declarations cannot target disabled VMs: ${formatList policyDisabledTargets}";
      }
      {
        assertion = policySelfEdges == [ ];
        message = "sys.virtualisation.microvm network policy cannot declare self-edges: ${formatList policySelfEdges}";
      }
      {
        assertion = policyDedicatedEdges == [ ];
        message = "sys.virtualisation.microvm dedicated-bridge VMs cannot have direct VM peer permissions: ${formatList policyDedicatedEdges}";
      }
      {
        assertion = policyMissingReasons == [ ];
        message = "sys.virtualisation.microvm network policy permissions require a non-empty reason: ${formatList policyMissingReasons}";
      }
      {
        assertion = policyEmptyServices == [ ];
        message = "sys.virtualisation.microvm network policy permissions must select the primary service or explicit ports: ${formatList policyEmptyServices}";
      }
      {
        assertion = policyDuplicatePorts == [ ];
        message = "sys.virtualisation.microvm network policy permissions contain duplicate ports: ${formatList policyDuplicatePorts}";
      }
      {
        assertion = disabledRegisteredGateways == [ ];
        message = "sys.virtualisation.microvm enabled VMs reference disabled registered gateway VMs: ${formatList disabledRegisteredGateways}";
      }
      {
        assertion = dedicatedRegisteredGateways == [ ];
        message = "sys.virtualisation.microvm registered VM gateway relationships must stay on the shared bridge: ${formatList dedicatedRegisteredGateways}";
      }
    ];

    microvm = {
      autostart = derivedAutostart;
      vms = derivedVms;
      inherit (cfg) stateDir;
    };

    boot.kernelModules = [ "nf_conntrack_bridge" ];

    environment = {
      etc."microvm-network-policy/ruleset.nft".source = policyRuleset;
      systemPackages = [ pkgs.nftables ];
    };

    systemd = {
      # Bridges for MicroVM traffic (systemd-networkd style).
      network = {
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
            networkConfig = {
              Address = [ "10.100.0.1/24" ];
              LinkLocalAddressing = "no";
            };
            neighbors = sharedBridgeNeighbors;
          };

          # Unknown vm-* taps still attach to the shared bridge, but cannot
          # transmit through nftables or receive flooded unicast/multicast.
          "12-microvm-tap" = {
            matchConfig.Name = "vm-*";
            networkConfig.Bridge = "microvm-br0";
            bridgeConfig = {
              Learning = true;
              Locked = false;
              MulticastFlood = false;
              UnicastFlood = false;
            };
          };
        }
        // isolatedBridgeNetworks
        // registeredTapNetworks;
      };

      services = {
        microvm-network-policy = {
          description = "Atomic MicroVM bridge identity and lateral-access policy";
          wantedBy = [ "multi-user.target" ];
          after = [ "systemd-modules-load.service" ];
          before = [ "microvms.target" ] ++ policyVmUnitNames ++ policyTapUnitNames;
          restartTriggers = [ policyRuleset ];

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${pkgs.nftables}/bin/nft --file ${policyRuleset}";
            CapabilityBoundingSet = [ "CAP_NET_ADMIN" ];
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectHome = true;
            ProtectSystem = "strict";
          };
        };
      }
      // policyUnitOverrides;
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

      # The normal NixOS firewall continues to own host INPUT. The dedicated
      # native nftables policy only authenticates VM frames and filters traffic
      # forwarded between VM ports/bridges.
      # Add interfaces."microvm-br0".allowedTCPPorts here if a VM must reach
      # a specific host service directly.
      firewall.interfaces = {
        "microvm-br0" = {
          allowedTCPPorts = [ ];
          allowedUDPPorts = [ ];
        };
      }
      // isolatedFirewallInterfaces;
    };

    sys.services.cloudflared.ingress = lib.mkIf (config.sys.services.cloudflared.enable or false
    ) publicationIngress;

    services.traefik.dynamic.files.microvm-publications.settings.http = {
      routers = publicationRouters;
      services = publicationServices;
    };
  };
}
