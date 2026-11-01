{
  config,
  inputs,
  lib,
  consts,
  ...
}:
let
  reg = (import ./vm-registry.nix { inherit consts; }).cross-seed;
  cfg = config.sys.services.cross-seed;
  stateDir = "/var/lib/cross-seed";
in
{
  imports = [
    ./base.nix
    ../modules/services/cross-seed.nix
    inputs.sops-nix.nixosModules.sops
    (import ./mkMicrovmConfig.nix (
      reg
      // {
        volumes = [
          {
            mountPoint = stateDir;
            image = "cross-seed-state.img";
            size = 2048;
          }
        ];
        extraShares = [
          {
            source = "/rpool/unenc/media/data";
            mountPoint = "/data";
            tag = "media-data";
            proto = "virtiofs";
          }
        ];
      }
    ))
  ];

  assertions = [
    {
      assertion = cfg.dataDir == stateDir;
      message = "cross-seed-vm: sys.services.cross-seed.dataDir must remain ${stateDir}, where cross-seed-state.img is mounted. Moving state requires an explicit migration.";
    }
  ];

  # security.sudo.wheelNeedsPassword = lib.mkForce false;

  # Enabled operation is checked in. For a fresh/replacement guest, first set
  # enable = false: boot creates /persist/ssh/ssh_host_ed25519_key. Enroll its
  # public age recipient, provision cross-seed/settings in nix-secrets, and
  # complete storage maintenance before re-enabling searches/injections.
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
    defaultSopsFile = inputs.nix-secrets.secrets.secretsFile;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/persist/ssh/ssh_host_ed25519_key" ];
    useSystemdActivation = true;

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
