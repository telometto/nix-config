# Keep flake-backed adapter instances host-managed even with a manual update
# source. The pinned upstream installer otherwise skips existing VM directories.
{
  lib,
  stateDir,
  vms,
}:
lib.mapAttrs' (
  name: vm:
  let
    runner = vm.flake.nixosConfigurations.${name}.config.microvm.declaredRunner;
    flakeRef = if vm.updateFlake != null then vm.updateFlake else toString vm.flake;
  in
  lib.nameValuePair "install-microvm-${name}" {
    unitConfig.ConditionPathExists = lib.mkForce "";
    # Replace upstream's truncating reference write as well as its condition.
    # Retain upstream's unit dependencies and runner-derived restart behavior.
    script = lib.mkForce ''
      set -eu
      mkdir -p -- ${lib.escapeShellArg "${stateDir}/${name}"}
      cd -- ${lib.escapeShellArg "${stateDir}/${name}"}
      chown microvm:kvm .

      reference_tmp=$(mktemp .flake.XXXXXX)
      trap 'rm -f -- "$reference_tmp"' EXIT
      printf '%s\n' ${lib.escapeShellArg flakeRef} > "$reference_tmp"
      chown microvm:kvm "$reference_tmp"
      chmod 0644 "$reference_tmp"
      mv -fT -- "$reference_tmp" flake

      ln -sTf -- ${lib.escapeShellArg (toString runner)} current
      chown -h microvm:kvm current
    '';
  }
) (lib.filterAttrs (_: vm: vm.flake != null) vms)
