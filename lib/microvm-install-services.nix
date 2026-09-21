# Keep flake-backed adapter instances host-managed even with a manual update
# source. The pinned upstream installer otherwise skips existing VM directories.
{
  lib,
  stateDir,
  vms,
}:
lib.concatMapAttrs (
  name: vm:
  let
    runner = vm.flake.nixosConfigurations.${name}.config.microvm.declaredRunner;
    flakeRef = if vm.updateFlake != null then vm.updateFlake else toString vm.flake;
  in
  {
    "microvm-set-booted@${name}" = {
      # Host switches submit separate start jobs. Pull installation into this
      # transaction so upstream's Before= ordering applies before reading current.
      # Wants (not Requires) lets the installer update without stopping booted
      # when restartIfChanged is false.
      wants = [ "install-microvm-${name}.service" ];
      overrideStrategy = "asDropin";
      path = lib.mkForce [ ];
      restartIfChanged = false;
    };
    "install-microvm-${name}" = {
      # Keep installation active so pulling it into a VM start is a no-op until
      # the host configuration changes the installer (including on rollback).
      serviceConfig.RemainAfterExit = true;
      # A manual VM restart must retain runners selected by microvm -Ru.
      # Only host configuration changes should restart this installer.
      partOf = lib.mkForce [ ];
      unitConfig.ConditionPathExists = lib.mkForce "";
      # Replace upstream's truncating reference write as well as its condition.
      # Retain upstream's ordering and runner-derived restart behavior.
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
    };
  }
) (lib.filterAttrs (_: vm: vm.flake != null) vms)
