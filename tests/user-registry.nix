# Public-only evaluation (no private data or activation):
# nix eval --offline --impure --json --expr '
#   let
#     lock = builtins.fromJSON (builtins.readFile ./flake.lock);
#     source = builtins.fetchTree lock.nodes.${lock.nodes.${lock.root}.inputs.nixpkgs}.locked;
#   in (import ./tests/user-registry.nix {
#     pkgs = import source { system = "x86_64-linux"; };
#   }).cases'
{ pkgs }:
let
  inherit (pkgs) lib;
  normalize = users: import ../lib/user-registry.nix { inherit lib users; };
  ordered = normalize {
    alpha = {
      user = "bob";
      marker = "first";
    };
    zulu = {
      user = "alice";
      uid = 1101;
      marker = "second";
    };
  };
  fallbacks = normalize {
    missing = {
      marker = "missing";
    };
    nullName = {
      user = null;
    };
    empty = {
      user = "";
    };
    nonString = {
      user = 42;
    };
    whitespace = {
      user = " ";
    };
  };
  duplicates = normalize {
    first = {
      user = "alice";
      uid = 1101;
      marker = "first";
    };
    second = {
      user = "alice";
      uid = 9999;
      marker = "second";
    };
  };
  collision = normalize {
    alice = {
      user = null;
      marker = "fallback";
    };
    zulu = {
      user = "alice";
      marker = "login";
    };
  };
  lazy = normalize {
    owner = {
      user = "alice";
      hashedPassword = throw "Synthetic credential must not be forced by normalization";
    };
  };
  cases = {
    normalization = {
      emptyRegistry = (normalize { }).records == [ ] && (normalize { }).byUsername == { };
      loginsKeyTheMap =
        builtins.attrNames ordered.byUsername == [
          "alice"
          "bob"
        ];
      roleOrderingAndRawFieldsPreserved =
        map (r: {
          inherit (r) roleName username uid;
        }) ordered.records == [
          {
            roleName = "alpha";
            username = "bob";
            uid = null;
          }
          {
            roleName = "zulu";
            username = "alice";
            uid = 1101;
          }
        ];
      payloadPreserved =
        ordered.byUsername.alice == {
          user = "alice";
          uid = 1101;
          marker = "second";
        };
      recordCarriesOriginalPayload =
        (builtins.head ordered.records).userData == {
          user = "bob";
          marker = "first";
        };
      invalidLoginsKeepRoleKeys =
        builtins.attrNames fallbacks.byUsername == [
          " "
          "empty"
          "missing"
          "nonString"
          "nullName"
        ];
      invalidFieldsAreNotCoerced =
        fallbacks.byUsername.nonString.user == 42
        && fallbacks.byUsername.nullName.user == null
        && fallbacks.byUsername.empty.user == "";
      firstDuplicateWinsLookup = duplicates.byUsername.alice.marker == "first";
      everyDuplicateRecordRetained =
        map (r: r.uid) duplicates.records == [
          1101
          9999
        ];
      fallbackCollisionOrderingPreserved = collision.byUsername.alice.marker == "fallback";
      usernamePredicateUnchanged =
        ordered.isValidUsername "alice"
        && ordered.isValidUsername " "
        && !(ordered.isValidUsername "")
        && !(ordered.isValidUsername null)
        && !(ordered.isValidUsername 42);
      normalizationDoesNotForceCredentials =
        builtins.attrNames lazy.byUsername == [ "alice" ] && builtins.length lazy.records == 1;
    };
    consumers = import ./user-registry-modules.nix { inherit pkgs; };
  };
  failures = lib.concatLists (
    lib.mapAttrsToList (
      group: tests:
      map (name: "${group}.${name}") (builtins.attrNames (lib.filterAttrs (_: passed: !passed) tests))
    ) cases
  );
in
assert lib.assertMsg (
  failures == [ ]
) "User registry contracts failed: ${lib.concatStringsSep ", " failures}";
pkgs.runCommand "user-registry-tests" { passthru = { inherit cases; }; } ''
  touch "$out"
''
