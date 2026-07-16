# Pure IPv4 helpers shared by guest and registry validation.
let
  digitValues = {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
  };

  stringToCharacters =
    value: builtins.genList (index: builtins.substring index 1 value) (builtins.stringLength value);

  parseDecimal =
    value:
    builtins.foldl' (result: digit: result * 10 + digitValues.${digit}) 0 (stringToCharacters value);

  parse =
    value:
    if !builtins.isString value then
      null
    else
      let
        parts = builtins.match "([0-9][0-9]?[0-9]?)\\.([0-9][0-9]?[0-9]?)\\.([0-9][0-9]?[0-9]?)\\.([0-9][0-9]?[0-9]?)" value;
      in
      if parts == null then
        null
      else
        let
          octets = map parseDecimal parts;
        in
        if builtins.all (octet: octet <= 255) octets then
          builtins.foldl' (result: octet: result * 256 + octet) 0 octets
        else
          null;

  pow2 = exponent: if exponent == 0 then 1 else 2 * pow2 (exponent - 1);

  validPrefix = prefixLength: builtins.isInt prefixLength && prefixLength >= 0 && prefixLength <= 32;

  networkInterval =
    address: prefixLength:
    let
      parsedAddress = parse address;
    in
    if parsedAddress == null || !validPrefix prefixLength then
      null
    else
      let
        blockSize = pow2 (32 - prefixLength);
        first = (parsedAddress / blockSize) * blockSize;
      in
      {
        inherit first;
        last = first + blockSize - 1;
      };

  sameSubnet =
    left: right: prefixLength:
    let
      leftNetwork = networkInterval left prefixLength;
      rightNetwork = networkInterval right prefixLength;
    in
    leftNetwork != null && rightNetwork != null && leftNetwork.first == rightNetwork.first;

  usableHostAddress =
    address: prefixLength:
    let
      parsedAddress = parse address;
      interval = networkInterval address prefixLength;
    in
    interval != null
    && prefixLength >= 1
    && prefixLength <= 31
    && (prefixLength == 31 || (parsedAddress > interval.first && parsedAddress < interval.last));
in
{
  inherit
    networkInterval
    parse
    sameSubnet
    usableHostAddress
    validPrefix
    ;
}
