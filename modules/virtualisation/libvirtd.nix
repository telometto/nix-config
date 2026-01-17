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
        ovmf = {
          enable = true;
          packages = [ pkgs.OVMFFull.fd ];
        };
      };
    };

    # Add virsh and virt-manager tools
    environment.systemPackages = with pkgs; [
      libvirt
      virt-manager
      virt-viewer
    ];

    # Allow users in libvirtd group to manage VMs
    users.groups.libvirtd.members = [ ];

    # Firewall rules for VM networking
    networking.firewall.trustedInterfaces = [ cfg.networkBridge ];
  };
}
