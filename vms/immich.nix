{
  config,
  inputs,
  VARS,
  lib,
  ...
}:
let
  reg = (import ./vm-registry.nix).immich;
  # Pocket ID assigns this public identifier. Keep it in sync with the
  # restricted Immich client documented in docs/immich.md.
  oauthClientId = "52bc6bc3-5c98-4f4b-bd00-b27318fd7801";
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
      # Immich 2.7+ ships a CSP that is kept in sync with its frontend.
      IMMICH_HELMET_FILE = "true";
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
        clientId = oauthClientId;
        clientSecret._secret = config.sops.secrets."immich/oauth_client_secret".path;
        # The authenticated linking flow needs only the stable OIDC subject.
        # Omitting email keeps login callbacks out of Immich 2.7.5's unsafe
        # automatic email-linking branch.
        scope = "openid profile";
        signingAlgorithm = "RS256";
        profileSigningAlgorithm = "none";
        tokenEndpointAuthMethod = "client_secret_post";
        buttonText = "Login with Pocket ID";
        # Existing accounts must be linked from an authenticated user-settings
        # session before OAuth is used to log in. See docs/immich.md.
        autoRegister = false;
        autoLaunch = false;
      };
      # Keep a tested local administrator path if Pocket ID is unavailable.
      passwordLogin.enabled = true;
      server.externalDomain = "https://photos.${VARS.domains.public}";
      storageTemplate.enabled = true;
    };
  };

  # sops-nix queues restartUnits before atomically switching /run/secrets.
  # This ordering makes systemd defer Immich's credential snapshot until the
  # new secret generation is active.
  systemd.services.immich-server = {
    after = [ "sops-install-secrets.service" ];
    requires = [ "sops-install-secrets.service" ];
  };
}
