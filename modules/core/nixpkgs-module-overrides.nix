# Temporary NixOS module overrides - pin a fixed module from a different
# nixpkgs input while waiting for a fix to propagate to the primary channel.
#
# Pattern:
#   disabledModules = [ "<relative/path>.nix" ];   # disable buggy version
#   imports = [ "${inputs.<input>}/nixos/modules/<relative/path>.nix" ];
#
# Remove each entry once `nix flake update` picks up the upstream fix.
_: {
  #   # https://github.com/NixOS/nixpkgs/issues/511465
  #   # pam.nix generates non-absolute PAM module paths (e.g. "login") in
  #   # security.apparmor.includes; AppArmor rejects them.
  #   # Fix: https://github.com/NixOS/nixpkgs/pull/511479 (merged nixos-unstable-small)
  #   disabledModules = [ "security/pam.nix" ];
  #   imports = [ "${inputs.nixpkgs-unstable}/nixos/modules/security/pam.nix" ];
}
