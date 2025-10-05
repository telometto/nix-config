{
  lib,
  VARS,
  inputs,
  ...
}:
{
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-p51
    ./hardware-configuration.nix
    ./packages.nix
  ];

  networking = {
    hostName = lib.mkForce "avalanche";
    hostId = lib.mkForce "31a76aff";
  };

  telometto = {
    role.desktop.enable = true;

    desktop.flavor = "gnome";

    # User-specific configuration for admin user on avalanche
    home.users.${VARS.users.zeno.user} = {
      extraModules = [ ../../home/users/user-configs/admin-avalanche.nix ];
    };

    # networking = {
    #   firewall = {
    #     extraTCPPortRanges = [{
    #       from = 1714;
    #       to = 1764;
    #     }];
    #     extraUDPPortRanges = [{
    #       from = 1714;
    #       to = 1764;
    #     }];
    #   };
    # };

    services = {
      tailscale.interface = "changeme";

      # nfs = {
      #   enable = true;
      #   server = {
      #     enable = true;
      #     exports = ''
      #       /run/media/zeno/personal/nfs-oldie 192.168.2.0/24(rw,sync,nohide,no_subtree_check)
      #     '';
      #     openFirewall = false;
      #   };
      # };
    };

    # storage = {
    #   filesystems = {
    #     enable = true;

    #     mounts = {
    #       personal = {
    #         device = "76177a35-e3a1-489f-9b21-88a38a0c1d3e";
    #         mountPoint = "personal";
    #         options = [ "defaults" ]; # Primary drive - no nofail
    #       };

    #       samsung = {
    #         device = "e7e653c3-361c-4fb2-a65e-13fdcb1e6e25";
    #         mountPoint = "samsung";
    #         options = [ "defaults" "nofail" ]; # Secondary drive - with nofail
    #       };
    #     };

    #     # autoScrub.enable = true by default
    #     # autoScrub.interval = "weekly" by default
    #   };
    # };
  };
  hardware = {
    cpu.intel.updateMicrocode = lib.mkDefault true;
  };

  # Additional services
  programs.virt-manager.enable = true;

  # System version
  system.stateVersion = "24.05";
}
