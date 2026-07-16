# Pure evaluation-time validation for the MicroVM registry.
# Returns the original registry unchanged so existing callers still receive a plain attrset.
registry:
let
  ipv4 = import ./ipv4.nix;
  unique = values:
    builtins.foldl' (result: value: if builtins.elem value result then result else result ++ [ value ]) [ ] values;
  duplicateValues = values:
    builtins.filter
      (value: builtins.length (builtins.filter (candidate: candidate == value) values) > 1)
      (unique values);

  entries = builtins.attrValues registry;
  entryName = entry: entry.name or "<unnamed>";
  fieldValues = field: map (entry: toString entry.${field}) entries;
  prefixFor = entry: entry.prefixLength or 24;
  gatewayFor = entry: entry.gateway or "10.100.0.1";
  tapIdFor = entry: entry.tapId or "vm-${entryName entry}";
  duplicateCids = duplicateValues (fieldValues "cid");
  duplicateMacs = duplicateValues (fieldValues "mac");
  duplicateIps = duplicateValues (fieldValues "ip");
  duplicatePorts = duplicateValues (fieldValues "port");
  prefixIsValid = entry:
    ipv4.validPrefix (prefixFor entry) && (prefixFor entry) >= 1 && (prefixFor entry) <= 31;
  invalidPrefixes = builtins.filter (entry: !prefixIsValid entry) entries;
  invalidIps = builtins.filter (entry: ipv4.parse (entry.ip or null) == null) entries;
  invalidGateways = builtins.filter (entry: ipv4.parse (gatewayFor entry) == null) entries;
  mismatchedSubnets = builtins.filter
    (entry:
      prefixIsValid entry
      && ipv4.parse (entry.ip or null) != null
      && ipv4.parse (gatewayFor entry) != null
      && !(ipv4.sameSubnet entry.ip (gatewayFor entry) (prefixFor entry)))
    entries;
  unusableIps = builtins.filter
    (entry:
      prefixIsValid entry
      && ipv4.parse (entry.ip or null) != null
      && !(ipv4.usableHostAddress entry.ip (prefixFor entry)))
    entries;
  unusableGateways = builtins.filter
    (entry:
      prefixIsValid entry
      && ipv4.parse (gatewayFor entry) != null
      && !(ipv4.usableHostAddress (gatewayFor entry) (prefixFor entry)))
    entries;
  identicalIpGateways = builtins.filter
    (entry:
      ipv4.parse (entry.ip or null) != null
      && ipv4.parse (gatewayFor entry) != null
      && ipv4.parse entry.ip == ipv4.parse (gatewayFor entry))
    entries;

  invalidTapIds = builtins.filter
    (entry: !builtins.isString (tapIdFor entry) || tapIdFor entry == "")
    entries;
  duplicateTapIds = duplicateValues (map tapIdFor entries);

  sharedEntries = builtins.filter (entry: !(entry ? hostBridge)) entries;
  dedicatedEntries = builtins.filter (entry: entry ? hostBridge) entries;
  missingDedicatedGateways = builtins.filter (entry: !(entry ? gateway)) dedicatedEntries;
  invalidHostBridges = builtins.filter
    (entry: !builtins.isString entry.hostBridge || entry.hostBridge == "")
    dedicatedEntries;
  reservedHostBridges = builtins.filter
    (entry: entry.hostBridge == "microvm-br0")
    dedicatedEntries;
  duplicateHostBridges = duplicateValues (map (entry: entry.hostBridge) dedicatedEntries);
  networkInterval = entry: ipv4.networkInterval entry.ip (prefixFor entry);
  networksOverlap = left: right:
    left.first <= right.last && right.first <= left.last;
  sharedNetwork = ipv4.networkInterval "10.100.0.0" 24;
  invalidSharedNetworks = builtins.filter
    (entry:
      prefixIsValid entry
      && ipv4.parse (entry.ip or null) != null
      && (prefixFor entry != 24 || (networkInterval entry).first != sharedNetwork.first))
    sharedEntries;
  sharedNetworkOverlaps = builtins.concatLists (map
    (entry:
      if networksOverlap (networkInterval entry) sharedNetwork then
        [ "${entryName entry} (${entry.hostBridge}) overlaps shared network 10.100.0.0/24" ]
      else
        [ ])
    dedicatedEntries);
  dedicatedNetworkOverlaps = builtins.concatLists (builtins.genList
    (leftIndex:
      let
        left = builtins.elemAt dedicatedEntries leftIndex;
        leftNetwork = networkInterval left;
      in
      builtins.concatLists (builtins.genList
        (rightOffset:
          let
            right = builtins.elemAt dedicatedEntries (leftIndex + rightOffset + 1);
          in
          if networksOverlap leftNetwork (networkInterval right) then
            [ "${entryName left} (${left.hostBridge}) and ${entryName right} (${right.hostBridge})" ]
          else
            [ ])
        (builtins.length dedicatedEntries - leftIndex - 1)))
    (builtins.length dedicatedEntries));
  overlappingNetworks = sharedNetworkOverlaps ++ dedicatedNetworkOverlaps;

  firstName = invalidEntries: entryName (builtins.head invalidEntries);
  fail = message: builtins.throw "vm-registry: ${message}";
in
if duplicateCids != [ ] then
  fail "CIDs must be unique; duplicate(s): ${builtins.concatStringsSep ", " duplicateCids}"
else if duplicateMacs != [ ] then
  fail "MAC addresses must be unique; duplicate(s): ${builtins.concatStringsSep ", " duplicateMacs}"
else if duplicateIps != [ ] then
  fail "IP addresses must be unique; duplicate(s): ${builtins.concatStringsSep ", " duplicateIps}"
else if duplicatePorts != [ ] then
  fail "service ports must be unique; duplicate(s): ${builtins.concatStringsSep ", " duplicatePorts}"
else if invalidPrefixes != [ ] then
  fail "${firstName invalidPrefixes}.prefixLength must be an integer between 1 and 31"
else if invalidIps != [ ] then
  fail "${firstName invalidIps}.ip must be a valid IPv4 address"
else if missingDedicatedGateways != [ ] then
  fail "${firstName missingDedicatedGateways}.gateway is required when hostBridge is set"
else if invalidGateways != [ ] then
  fail "${firstName invalidGateways}.gateway must be a valid IPv4 address"
else if mismatchedSubnets != [ ] then
  let
    entry = builtins.head mismatchedSubnets;
  in
  fail "${entryName entry}: ip ${entry.ip} and gateway ${gatewayFor entry} are not in the same /${toString (prefixFor entry)} subnet"
else if unusableIps != [ ] then
  fail "${firstName unusableIps}.ip must be a usable host address, not a network or broadcast endpoint"
else if unusableGateways != [ ] then
  fail "${firstName unusableGateways}.gateway must be a usable host address, not a network or broadcast endpoint"
else if identicalIpGateways != [ ] then
  fail "${firstName identicalIpGateways}.ip and gateway must be different addresses"
else if invalidSharedNetworks != [ ] then
  fail "${firstName invalidSharedNetworks} must use shared network 10.100.0.0/24 unless hostBridge is set"
else if invalidTapIds != [ ] then
  fail "${firstName invalidTapIds} has an empty or non-string effective tap ID"
else if duplicateTapIds != [ ] then
  fail "effective tap IDs must be unique; duplicate(s): ${builtins.concatStringsSep ", " duplicateTapIds}"
else if invalidHostBridges != [ ] then
  fail "${firstName invalidHostBridges}.hostBridge must be a non-empty string"
else if reservedHostBridges != [ ] then
  fail "${firstName reservedHostBridges}.hostBridge must not reuse shared bridge microvm-br0"
else if duplicateHostBridges != [ ] then
  fail "dedicated hostBridge names must be unique; duplicate(s): ${builtins.concatStringsSep ", " duplicateHostBridges}"
else if overlappingNetworks != [ ] then
  fail "dedicated hostBridge networks must not overlap another dedicated network or 10.100.0.0/24: ${builtins.concatStringsSep ", " overlappingNetworks}"
else
  registry
