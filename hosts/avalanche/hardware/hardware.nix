{ config, inputs, lib, pkgs, ... }:

{
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-p51 # Lenovo ThinkPad P51 hardware configuration
    # inputs.nixos-hardware.nixosModules.common-cpu-intel # Intel CPU microcode updates

    # inputs.nixos-hardware.nixosModules.common-gpu-intel # Intel GPU drivers
    # inputs.nixos-hardware.nixosModules.common-gpu-intel-kaby-lake # Intel Kaby Lake GPU drivers

    # inputs.nixos-hardware.nixosModules.common-gpu-nvidia # NVIDIA GPU drivers

    # inputs.nixos-hardware.nixosModules.common-pc-laptop # Laptop optimizations
    # inputs.nixos-hardware.nixosModules.common-pc-laptop-acpi_call # ACPI call for laptop battery optimization
    # inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd # SSD optimizations
  ];
}
