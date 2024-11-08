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
