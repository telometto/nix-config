/**
 * This NixOS module configures virtualization settings for libvirt and QEMU/KVM.
 * It enables libvirtd, configures QEMU to run as root, and sets up secure boot
 * and TPM support for OVMF (Open Virtual Machine Firmware).
 *
 * - Enables libvirtd service.
 * - Configures QEMU to use the KVM package and run as root.
 * - Enables and configures swtpm (software TPM).
 * - Enables OVMF with secure boot and TPM support.
 * - Adds libvirt, qemu, and OVMFFull to the system packages.
 */

{ config, lib, pkgs, ... }:

{
  virtualisation = {
    libvirtd = {
      enable = true;

      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = true;
        swtpm.enable = true;

        ovmf = {
          enable = true;
          packages = [
            (pkgs.OVMF.override {
              secureBoot = true;
              tpmSupport = true;
            }).fd
          ];
        };
      };
    };
  };

  environment.systemPackages = with pkgs; [
    libvirt
    qemu
    OVMFFull
  ];
}
