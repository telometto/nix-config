/**
 * This NixOS module configuration file is used for setting up virtualization
 * using microVMs. It imports necessary modules for either host or guest
 * configurations.
 *
 * The `imports` attribute includes:
 * - `inputs.microvm.nixosModules.host`: This module is imported for host configurations.
 * - `inputs.microvm.nixosModules.microvm`: This module can be uncommented and used for guest configurations.
 *
 * To use this configuration, place it in the appropriate directory within your NixOS configuration structure.
 */

{ config, inputs, lib, pkgs, ... }:

{
  imports = [
    inputs.microvm.nixosModules.host # For hosts
    # inputs.microvm.nixosModules.microvm # For guests
  ];
}
