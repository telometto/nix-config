{
  lib,
  config,
  ...
}:
let
  cfg = config.sys.virtualisation;
in
{
  options.sys.virtualisation.enable = lib.mkEnableOption "Virtualisation stack (podman, containers, libvirt, virt-manager)";
  config = lib.mkIf cfg.enable {
    virtualisation = {
      podman = {
        enable = lib.mkDefault true;
        dockerCompat = lib.mkDefault true;
        dockerSocket.enable = lib.mkDefault true;
        autoPrune.enable = lib.mkDefault true;
        defaultNetwork.settings.dns_enabled = lib.mkDefault true;
      };
      containers.enable = lib.mkDefault true;
      quadlet.enable = lib.mkDefault true;
    };
    programs.virt-manager.enable = lib.mkDefault false;
  };
}
