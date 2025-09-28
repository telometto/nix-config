{ lib, config, ... }:
let cfg = config.telometto.networking.networkmanager;
in {
  options.telometto.networking.networkmanager = {
    enable = lib.mkEnableOption "NetworkManager service";
  };
  config = lib.mkIf cfg.enable {
    networking = {
      networkmanager = {
        enable = lib.mkDefault true;
        dns = lib.mkDefault "systemd-resolved";
      };
      useNetworkd = lib.mkForce false;
      useDHCP = lib.mkDefault true;
    };
    systemd.network.enable = lib.mkForce false;

  };
}
