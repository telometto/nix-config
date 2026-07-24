{
  config,
  inputs,
  VARS,
  lib,
  ...
}:
let
  reg = (import ./vm-registry.nix).immich;
in
{
  imports = [
    ./base.nix
    ../modules/services/immich.nix
    inputs.sops-nix.nixosModules.sops
    (import ./mkMicrovmConfig.nix (
      reg
      // {
        volumes = [
          {
            mountPoint = "/var/lib/immich";
            image = "immich-state.img";
            size = 1048576;
          }
          {
            mountPoint = "/var/lib/postgresql";
            image = "postgresql-state.img";
            size = 10240;
          }
        ];
      }
    ))
  ];

  # security.sudo.wheelNeedsPassword = lib.mkForce false;

  # SOPS configuration for this MicroVM
  # After first boot, get the VM's age key with:
  #   ssh admin@10.100.0.70 "sudo cat /persist/ssh/ssh_host_ed25519_key" | ssh-to-age
  # Then add it to your .sops.yaml and re-encrypt secrets
  sops = {
    defaultSopsFile = inputs.nix-secrets.secrets.secretsFile;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/persist/ssh/ssh_host_ed25519_key" ];
    useSystemdActivation = true;

    secrets."immich/oauth_client_secret" = {
      owner = "immich";
      group = "immich";
      mode = "0400";
      restartUnits = [ "immich-server.service" ];
    };
  };

  networking.firewall.allowedTCPPorts = [ reg.port ];

  systemd.tmpfiles.rules = [
    "d /var/lib/immich 0700 immich immich -"
    "d /var/lib/postgresql 0700 postgres postgres -"
  ];

  sys.services.immich = {
    enable = true;
    host = "0.0.0.0";
    inherit (reg) port;
    openFirewall = true;

    environment = {
      TZ = "Europe/Oslo";
      IMMICH_ALLOW_SETUP = "false";
      IMMICH_LOG_LEVEL = "log";
      IMMICH_TRUSTED_PROXIES = "10.100.0.1";
    };

    ml.enable = false;

    settings = {
      machineLearning = {
        clip.modelName = "ViT-SO400M-16-SigLIP2-384__webli";
        ocr.modelName = "LATIN__PP-OCRv5_mobile";
        urls = [
          "http://10.100.0.1:3003"
        ];
      };
      oauth = {
        enabled = true;
        issuerUrl = "https://id.${VARS.domains.public}";
        clientId = "52bc6bc3-5c98-4f4b-bd00-b27318fd7801";
        clientSecret._secret = config.sops.secrets."immich/oauth_client_secret".path;
        scope = "openid email profile";
        signingAlgorithm = "RS256";
        profileSigningAlgorithm = "none";
        tokenEndpointAuthMethod = "client_secret_post";
        buttonText = "Login with Pocket ID";
        autoRegister = true;
        autoLaunch = true;
      };
      passwordLogin.enabled = false;
      server.externalDomain = "https://photos.${VARS.domains.public}";
      storageTemplate.enabled = true;
    };
  };
}
