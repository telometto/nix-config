# NOTE: OVMF (UEFI firmware, including Secure Boot + TPM variants) is
# automatically provided by the upstream NixOS module via the QEMU package.
# No explicit ovmf configuration is needed.
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sys.virtualisation.libvirtd;
in
{
  options.sys.virtualisation.libvirtd = {
    enable = lib.mkEnableOption "libvirtd for running VMs";

    networkBridge = lib.mkOption {
      type = lib.types.str;
      default = "virbr0";
      description = "Network bridge for VMs";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = false;
        swtpm.enable = true;
        vhostUserPackages = [ pkgs.virtiofsd ];
      };
    };

    programs.virt-manager.enable = true;

    # swtpm_localca needs a writable state directory owned by tss:tss
    systemd.tmpfiles.rules = [
      "d /var/lib/swtpm-localca 0750 tss tss -"
    ];

    environment.systemPackages = with pkgs; [
      libvirt
      virt-viewer
      dnsmasq
      virtio-win
    ];

    networking.firewall.trustedInterfaces = [ cfg.networkBridge ];
  };
}
