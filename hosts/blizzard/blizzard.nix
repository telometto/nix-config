{ lib, config, VARS, pkgs, ... }: {
  # Enable server role (provides server defaults)
  telometto.role.server.enable = true;

  imports = [ ./hardware-configuration.nix ./packages.nix ];

  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
  networking.hostName = lib.mkForce VARS.systems.server.hostName;
  networking.hostId = lib.mkForce VARS.systems.server.hostId;
  # Firewall policy via owner module (role enables it); host adds extra ports/ranges
  telometto.networking.firewall = {
    enable = true;
    extraTCPPortRanges = [{
      from = 4000;
      to = 4002;
    }];
    extraUDPPortRanges = [{
      from = 4000;
      to = 4002;
    }];
    # Include service ports for k3s, HTTP/HTTPS, NFS, Paperless, Actual, Searx, Scrutiny, Cockpit
    extraTCPPorts = [ 6443 80 443 111 2049 20048 28981 3838 7777 8072 9090 ];
    extraUDPPorts = [ 6443 80 443 111 2049 20048 28981 3838 7777 8072 9090 ];
  };

  # Private networking (enabled in legacy)
  telometto.services.tailscale.enable = lib.mkDefault true;
  services.networkd-dispatcher.rules."50-tailscale".script = lib.mkForce "${
      lib.getExe pkgs.ethtool
    } -K enp8s0 rx-udp-gro-forwarding on rx-gro-list off";

  # Enable NFS (owner module) and run as a server
  telometto.services.nfs = {
    enable = lib.mkDefault
      false; # matches legacy default (server block kept for quick flip)
    server = {
      enable = true;
      exports = ''
        /rpool/enc/transfers 192.168.2.0/24(rw,sync,nohide,no_subtree_check)
      '';
    };
  };

  # ZFS helpers and snapshot management
  telometto.services.zfs.enable = lib.mkDefault true;
  # Sanoid: rely on module default template "production" (autoprune=false) and just declare datasets
  telometto.services.sanoid = {
    enable = true;
    datasets = {
      tank = {
        useTemplate = [ "production" ];
        recursive = true;
      };
      flash_temp = {
        useTemplate = [ "production" ];
        recursive = true;
      };
    };
  };

  # Monitoring and admin UIs
  telometto.services.scrutiny.enable = lib.mkDefault true; # port 8072
  telometto.services.cockpit.enable = lib.mkDefault true; # port 9090

  # Kubernetes (k3s) server
  telometto.services.k3s.enable = lib.mkDefault true;

  # Maintenance bundle provided by role; host can override if needed

  # Apps and media
  telometto.services.paperless = {
    enable = lib.mkDefault false;
    consumptionDirIsPublic = lib.mkDefault true;
    consumptionDir = lib.mkDefault "/rpool/enc/personal/documents";
    mediaDir = lib.mkDefault "/rpool/enc/personal/paperless-media";
  };
  telometto.services.actual.enable = lib.mkDefault true; # port 3838
  telometto.services.firefly.enable =
    lib.mkDefault true; # APP_KEY_FILE via defaults
  telometto.services.searx.enable = lib.mkDefault true; # port 7777 bind 0.0.0.0
  telometto.services.immich = {
    enable = lib.mkDefault true;
    host = lib.mkDefault "0.0.0.0";
    port = lib.mkDefault 2283;
    openFirewall = lib.mkDefault true;
    mediaLocation = lib.mkDefault "/flash/enc/personal/immich-library";
    secretsFile = lib.mkDefault "/opt/sec/immich-file";
    environment = {
      IMMICH_LOG_LEVEL = "verbose";
      IMMICH_TELEMETRY_INCLUDE = "all";
    };
  };
  telometto.services.ombi = {
    enable = lib.mkDefault true;
    dataDir = lib.mkDefault "/rpool/unenc/apps/nixos/ombi";
  };
  telometto.services.plex.enable = lib.mkDefault true;
  telometto.services.tautulli = {
    enable = lib.mkDefault true;
    dataDir = lib.mkDefault "/rpool/unenc/apps/nixos/tautulli";
  };
  telometto.services.jellyfin.enable = lib.mkDefault true;

  # Virtualisation stack (podman, containers, libvirt)
  telometto.virtualisation.enable = lib.mkDefault true;

  # Client program defaults
  telometto.programs.ssh.enable = lib.mkDefault true;
  telometto.programs.mtr.enable = lib.mkDefault true;
  telometto.programs.gnupg.enable = lib.mkDefault true;

  # Automatic upgrades provided by role; host can override if needed

  # Backups: Borg (daily)
  telometto.services.borgbackup = {
    enable = lib.mkDefault true;
    jobs.homeserver = {
      paths = [ "/home/${VARS.users.admin.user}" ];
      environment.BORG_RSH =
        "ssh -o 'StrictHostKeyChecking=no' -i /home/${VARS.users.admin.user}/.ssh/borg-blizzard";
      repo = lib.mkDefault
        (config.telometto.secrets.borgRepo or "ssh://iu445agy@iu445agy.repo.borgbase.com/./repo");
      compression = "zstd,8";
      startAt = "daily";

      encryption = {
        mode = "repokey-blake2";
        passCommand = "cat ${config.telometto.secrets.borgKeyFile}";
      };
    };
  };

  # ZFS boot support (host-specific)
  boot = {
    supportedFilesystems = [ "zfs" ];
    initrd.supportedFilesystems.zfs = true;
    zfs = {
      forceImportAll = true;
      requestEncryptionCredentials = true;
      devNodes = "/dev/disk/by-id";
    };
    kernel.sysctl = {
      "net.ipv4.conf.all.src_valid_mark" = 1;
      "net.core.wmem_max" = 7500000;
      "net.core.rmem_max" = 7500000;
    };
  };

  systemd.network = {
    enable = lib.mkForce true;
    wait-online.enable = lib.mkForce true;
    networks."40-enp8s0" = {
      matchConfig.Name = "enp8s0";
      networkConfig = {
        DHCP = "yes";
        IPv6AcceptRA = true;
        IPv6PrivacyExtensions = "kernel";
      };
      linkConfig.RequiredForOnline = "routable";
    };
  };

  # Export kubeconfig for the admin user (used by server tooling)
  environment.variables.KUBECONFIG =
    "/home/${VARS.users.admin.user}/.kube/config";

  # Optional: enable or adjust service module settings at host level
  telometto.services.searx.port = lib.mkDefault 7777;
  telometto.services.actual.port = lib.mkDefault 3838;

  system.stateVersion = "24.11";
}
