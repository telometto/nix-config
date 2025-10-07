{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.telometto.virtualisation;
in
{
  options.telometto.virtualisation.enable = lib.mkEnableOption "Virtualisation stack (podman, containers, libvirt, virt-manager)";
  config = lib.mkIf cfg.enable {
    virtualisation = {
      podman = {
        enable = true;
        dockerCompat = true;
        dockerSocket.enable = true;
        autoPrune.enable = true;
        defaultNetwork.settings.dns_enabled = true;
      };
      containers.enable = true;
      oci-containers.backend = "podman";

      ## Error: The 'virtualisation.libvirtd.qemu.ovmf' submodule has been removed. All OVMF images distributed with QEMU are now available by default.
      # libvirtd = {
      #   enable = true;
      #   qemu = {
      #     package = pkgs.qemu_kvm;
      #     runAsRoot = lib.mkDefault true;
      #     swtpm.enable = lib.mkDefault true;
      #     ovmf = {
      #       enable = true;
      #       packages = [
      #         (pkgs.OVMF.override {
      #           secureBoot = true;
      #           tpmSupport = true;
      #         }).fd
      #       ];
      #     };
      #   };
      # };
    };
    programs.virt-manager.enable = lib.mkDefault false;
  };
}
