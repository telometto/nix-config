{
  config,
  lib,
  consts,
  ...
}:
let
  reg = (import ./vm-registry.nix { inherit consts; }).cross-seed;
  cfg = config.sys.services.cross-seed;
  mediaStorage = import ./media-storage.nix;
in
{
  imports = [
    ./base.nix
    ../modules/services/cross-seed.nix
    ./sops-base.nix
    (import ./mkMicrovmConfig.nix (
      reg
      // {
        volumes = [
          {
            mountPoint = "/var/lib/cross-seed";
            image = "cross-seed-state.img";
            size = 2048;
          }
        ];
        extraShares = [ mediaStorage.share ];
      }
    ))
  ];

  # security.sudo.wheelNeedsPassword = lib.mkForce false;

  # First boot creates /persist/ssh/ssh_host_ed25519_key. Enroll its public
  # age recipient and provision cross-seed/settings in nix-secrets before
  # enabling the daemon; it begins searching/injecting on startup.
  # See docs/cross-seed.md for the complete provisioning sequence.
  sys.services.cross-seed = {
    enable = true;
    inherit (reg) port;
  };

  # Prepare the account and link directory during bootstrap so permissions
  # can be tested as the actual service user before any searches are enabled.
  users = {
    groups.cross-seed = { };
    users.cross-seed = {
      isSystemUser = true;
      group = "cross-seed";
      extraGroups = [ "users" ];
      home = cfg.dataDir;
    };
  };

  systemd.tmpfiles.rules = lib.optionals (!cfg.enable) [
    "d ${cfg.linkDir} 2775 cross-seed users -"
  ];

  sops = {
    secrets = lib.mkIf cfg.enable {
      "cross-seed/settings" = {
        owner = "root";
        group = "root";
        mode = "0400";
        restartUnits = [ "cross-seed.service" ];
      };
    };
  };

  sys.secrets.crossSeedSettingsFile =
    lib.mkIf cfg.enable
      config.sops.secrets."cross-seed/settings".path;

  systemd.services.cross-seed = lib.mkIf cfg.enable {
    after = [ "sops-install-secrets.service" ];
    requires = [ "sops-install-secrets.service" ];
  };
}
