/**
 * This NixOS configuration enables and configures zram swap and the zram-generator service.
 *
 * Note: ZFS does not support swap on either zvols or swapfiles on ZFS datasets.
 *
 * - `zramSwap.enable`: Enables zram swap.
 * - `services.zram-generator.enable`: Enables the zram-generator service.
 * - `environment.systemPackages`: Installs the zram-generator package.
*/

{ config, lib, pkgs, ... }:

{
  zramSwap = {
    enable = true;
  };

  services.zram-generator = {
    enable = true;

    # settings = {};
  };

  environment.systemPackages = with pkgs; [ zram-generator ];
}
