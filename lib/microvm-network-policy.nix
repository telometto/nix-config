{
  lib,
  identities,
  serviceEdges,
  gatewayPairs,
  internalBridgeNames,
  mode,
}:
let
  escapeNftString =
    value:
    lib.replaceStrings
      [ "\\" "\"" "\n" "\r" ]
      [ "\\\\" "\\\"" " " " " ]
      value;
  quote = value: ''"${escapeNftString value}"'';
  quoteList = values: lib.concatStringsSep ", " (map quote values);
  addressList = values: lib.concatStringsSep ", " values;
  portList = values: lib.concatStringsSep ", " (map toString values);

  knownTapNames = map (identity: identity.tap) identities;
  knownVmAddresses = map (identity: identity.ip) identities;
  gateways = lib.unique (map (pair: pair.gateway) gatewayPairs);
  gatewayNames = map (gateway: gateway.name) gateways;
  knownDestinationRules = lib.concatMapStringsSep "\n" (identity: ''
    iifname @known_taps oifname ${quote identity.tap} jump undeclared_lateral
  '') identities;

  validationRules = lib.concatMapStringsSep "\n" (
    identity:
    let
      validateIpSource = !lib.elem identity.name gatewayNames;
    in
    ''
      iifname ${quote identity.tap} ether saddr != ${identity.mac} jump deny_spoof
      iifname ${quote identity.tap} ether type arp arp saddr ether != ${identity.mac} jump deny_spoof
      iifname ${quote identity.tap} ether type arp arp saddr ip != ${identity.ip} jump deny_spoof
      ${lib.optionalString validateIpSource ''
        iifname ${quote identity.tap} ether type ip ip saddr != ${identity.ip} jump deny_spoof
      ''}
      iifname ${quote identity.tap} ether type != { arp, ip } jump deny_invalid
      iifname ${quote identity.tap} accept
    ''
  ) identities;

  gatewayHostInputRules = lib.concatMapStringsSep "\n" (gateway: ''
    iifname ${quote gateway.tap} ether type ip ip saddr != ${gateway.ip} jump deny_spoof
  '') gateways;

  peerPairs = lib.unique (
    map (edge: {
      left = edge.source;
      right = edge.destination;
    }) serviceEdges
    ++ map (pair: {
      left = pair.client;
      right = pair.gateway;
    }) gatewayPairs
  );

  peerArpRules = lib.concatMapStringsSep "\n" (pair: ''
    iifname ${quote pair.left.tap} oifname ${quote pair.right.tap} ether type arp arp daddr ip ${pair.right.ip} accept
    iifname ${quote pair.right.tap} oifname ${quote pair.left.tap} ether type arp arp daddr ip ${pair.left.ip} accept
  '') peerPairs;

  serviceRules = lib.concatMapStringsSep "\n" (
    edge:
    let
      edgeComment = quote "${edge.source.name}->${edge.destination.name}: ${edge.reason}";
      forwardTcp = lib.optionalString (edge.tcpPorts != [ ]) ''
        iifname ${quote edge.source.tap} oifname ${quote edge.destination.tap} ether daddr ${edge.destination.mac} ip daddr ${edge.destination.ip} tcp dport { ${portList edge.tcpPorts} } ct state { new, established } accept comment ${edgeComment}
      '';
      forwardUdp = lib.optionalString (edge.udpPorts != [ ]) ''
        iifname ${quote edge.source.tap} oifname ${quote edge.destination.tap} ether daddr ${edge.destination.mac} ip daddr ${edge.destination.ip} udp dport { ${portList edge.udpPorts} } ct state { new, established } accept comment ${edgeComment}
      '';
    in
    ''
      ${forwardTcp}${forwardUdp}
      iifname ${quote edge.destination.tap} oifname ${quote edge.source.tap} ether daddr ${edge.source.mac} ip daddr ${edge.source.ip} ct state { established, related } accept comment ${edgeComment}
    ''
  ) serviceEdges;

  gatewayRules = lib.concatMapStringsSep "\n" (
    pair:
    let
      otherVmAddresses = lib.filter (address: address != pair.gateway.ip) knownVmAddresses;
    in
    ''
      ${lib.optionalString (otherVmAddresses != [ ]) ''
        iifname ${quote pair.client.tap} oifname ${quote pair.gateway.tap} ether daddr ${pair.gateway.mac} ip daddr { ${addressList otherVmAddresses} } jump deny_gateway_bypass
      ''}
      iifname ${quote pair.client.tap} oifname ${quote pair.gateway.tap} ether type ip ether daddr ${pair.gateway.mac} accept
      iifname ${quote pair.gateway.tap} oifname ${quote pair.client.tap} ether type ip ether daddr ${pair.client.mac} ip daddr ${pair.client.ip} accept
    ''
  ) gatewayPairs;

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

  routedIsolationRules = lib.concatMapStringsSep "\n" (pair: ''
    iifname ${quote pair.source} oifname ${quote pair.destination} jump deny_routed_lateral
    iifname ${quote pair.destination} oifname ${quote pair.source} jump deny_routed_lateral
  '') (mkBridgePairs internalBridgeNames);

  undeclaredLateralVerdict = if mode == "audit" then "accept" else "drop";
  undeclaredLateralCounter = if mode == "audit" then "lateral_audit" else "lateral_drops";
  undeclaredLateralPrefix =
    if mode == "audit" then "microvm-policy audit: " else "microvm-policy lateral-drop: ";
  knownTapSet = lib.optionalString (knownTapNames != [ ]) ''
    set known_taps {
      type ifname
      flags constant
      elements = { ${quoteList knownTapNames} }
    }
  '';
  knownTapMatch =
    if knownTapNames == [ ] then ''iifname "__no_registered_microvm_tap__"'' else "iifname @known_taps";

  bridgeRuleset = ''
    table bridge microvm_policy
    delete table bridge microvm_policy
    table bridge microvm_policy {
      counter spoof_drops {
        comment "Frames rejected for a forged registered identity"
      }

      counter invalid_drops {
        comment "Frames rejected for an unsupported or invalid protocol"
      }

      counter unknown_tap_drops {
        comment "Frames rejected because a vm-* tap is not enabled and registered"
      }

      counter multicast_drops {
        comment "Undeclared VM-to-VM broadcast and multicast frames"
      }

      counter gateway_bypass_drops {
        comment "VPN clients attempting to reach another VM through the gateway"
      }

      counter lateral_audit {
        comment "Undeclared registered lateral frames accepted during audit"
      }

      counter lateral_drops {
        comment "Undeclared registered lateral frames rejected in enforce mode"
      }

      ${knownTapSet}

      chain deny_spoof {
        counter name spoof_drops
        limit rate 10/minute burst 20 packets log prefix "microvm-policy spoof-drop: " level info
        drop
      }

      chain deny_invalid {
        counter name invalid_drops
        limit rate 10/minute burst 20 packets log prefix "microvm-policy invalid-drop: " level info
        drop
      }

      chain deny_unknown_tap {
        counter name unknown_tap_drops
        limit rate 10/minute burst 20 packets log prefix "microvm-policy unknown-tap: " level info
        drop
      }

      chain deny_multicast {
        counter name multicast_drops
        limit rate 10/minute burst 20 packets log prefix "microvm-policy multicast-drop: " level info
        drop
      }

      chain deny_gateway_bypass {
        counter name gateway_bypass_drops
        limit rate 10/minute burst 20 packets log prefix "microvm-policy gateway-bypass: " level info
        drop
      }

      chain undeclared_lateral {
        counter name ${undeclaredLateralCounter}
        limit rate 10/minute burst 20 packets log prefix ${quote undeclaredLateralPrefix} level info
        ${undeclaredLateralVerdict}
      }

      chain prerouting {
        type filter hook prerouting priority -300; policy accept;

        ${validationRules}
        iifname "vm-*" jump deny_unknown_tap
      }

      chain input {
        type filter hook input priority -300; policy accept;

        ${gatewayHostInputRules}
      }

      chain forward {
        type filter hook forward priority -300; policy accept;

        ${knownTapMatch} oifname "vm-*" ether type ip ct state invalid jump deny_invalid

        ${peerArpRules}
        ${gatewayRules}
        ${serviceRules}

        ${knownTapMatch} oifname "vm-*" ether daddr & 01:00:00:00:00:00 != 00:00:00:00:00:00 jump deny_multicast

        ${knownDestinationRules}
        ${knownTapMatch} oifname "vm-*" jump deny_unknown_tap
      }

      chain output {
        type filter hook output priority -300; policy accept;

        ${lib.concatMapStringsSep "\n" (identity: "oifname ${quote identity.tap} accept") identities}
        oifname "vm-*" jump deny_unknown_tap
      }
    }
  '';

  inetRuleset = ''
    table inet microvm_policy
    delete table inet microvm_policy
    table inet microvm_policy {
      counter routed_lateral_drops {
        comment "Packets rejected while routing between MicroVM bridge ports or bridges"
      }

      chain deny_routed_lateral {
        counter name routed_lateral_drops
        limit rate 10/minute burst 20 packets log prefix "microvm-policy routed-drop: " level info
        drop
      }

      chain forward {
        type filter hook forward priority -300; policy accept;

        iifname "microvm-br0" oifname "microvm-br0" jump deny_routed_lateral
        ${routedIsolationRules}
      }
    }
  '';
in
{
  ruleset = bridgeRuleset + "\n" + inetRuleset;
}
