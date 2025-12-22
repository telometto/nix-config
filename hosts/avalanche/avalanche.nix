{
  config,
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

    firewall = rec {
      enable = true;

      allowedTCPPorts = [ ];
      allowedUDPPorts = allowedTCPPorts;

      allowedTCPPortRanges = [ ];
      allowedUDPPortRanges = allowedTCPPortRanges;
    };
  };

  telometto = {
    role.desktop.enable = true;

    desktop.flavor = "gnome";

    users.zeno.enable = true;

    programs = {
      nix-ld.enable = true;
      python-venv.enable = true;
    };

    # Pull specific packages from different nixpkgs inputs
    # overlays.fromInputs = {
    #   nixpkgs-unstable = [ "intel-graphics-compiler" ];
    #   # nixpkgs-stable = [ "thunderbird" ];
    # };

    services = {
      tailscale = {
        interface = "wlp4s0";
        openFirewall = true;
      };

      cloudflareAccessIpUpdater = {
        enable = true;
        accountId = "1f65156829c5e18a3648609b381dec9c";
        policyId = "897e5beb-2937-448f-a444-4b51ff7479b0";
        apiTokenFile = config.sops.secrets."cloudflare/access_api_token".path;
        interval = "30min";
      };

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

  boot.extraModprobeConfig = ''
    # Keep Bluetooth coexistence disabled for better BT audio stability
    options iwlwifi bt_coex_active=0

    # Enable software crypto (helps BT coexistence sometimes)
    options iwlwifi swcrypto=1

    # Disable power saving on Wi-Fi module to reduce radio state changes that might disrupt BT
    options iwlwifi power_save=0

    # Disable Unscheduled Automatic Power Save Delivery (U-APSD) to improve BT audio stability
    options iwlwifi uapsd_disable=1

    # Disable D0i3 power state to avoid problematic power transitions
    options iwlwifi d0i3_disable=1

    # Set power scheme for performance (iwlmvm)
    options iwlmvm power_scheme=1
  '';

  hardware = {
    cpu.intel.updateMicrocode = lib.mkDefault true;

    bluetooth = {
      enable = true;

      powerOnBoot = true;
      settings = {
        General = {
          ControllerMode = "bredr"; # Fix frequent Bluetooth audio dropouts
          Experimental = true;
          FastConnectable = true;
        };

        Policy.AutoEnable = false;
      };
    };
  };

  programs.virt-manager.enable = true;

  system.stateVersion = "24.05";
}
