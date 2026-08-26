{
  matrix,
  blizzard,
  VARS,
  pkgs,
  ...
}:
let
  inherit (pkgs) lib;
  vmCfg = matrix.config;
  hostCfg = blizzard.config;
  bridge = vmCfg.services.mautrix-whatsapp;
  bridgeSettings = bridge.settings;
  bridgeService = vmCfg.systemd.services."mautrix-whatsapp";
  dbInitService = vmCfg.systemd.services."mautrix-whatsapp-db-init";
  registrationService = vmCfg.systemd.services."mautrix-whatsapp-registration";
  synapseService = vmCfg.systemd.services."matrix-synapse";
  bridgeVolume = lib.findFirst (
    volume: volume.mountPoint == "/var/lib/mautrix-whatsapp"
  ) null vmCfg.microvm.volumes;
  matrixInstance = hostCfg.sys.virtualisation.microvm.instances.matrix-synapse;
  bridgeAdmin = "@${VARS.users.zeno.user}:${VARS.domains.public}";
  bridgeEnvironment = vmCfg.sops.templates."matrix-whatsapp-environment";
  bridgeSecrets = [
    "matrix-whatsapp/appservice_as_token"
    "matrix-whatsapp/appservice_hs_token"
    "matrix-whatsapp/provisioning_shared_secret"
    "matrix-whatsapp/encryption_pickle_key"
    "matrix-whatsapp/public_media_signing_key"
    "matrix-whatsapp/direct_media_server_key"
  ];
in
assert bridge.enable;
assert bridge.registerToSynapse;
assert bridgeSettings.homeserver.address == "http://127.0.0.1:8008";
assert bridgeSettings.homeserver.domain == VARS.domains.public;
assert bridgeSettings.appservice.address == "http://127.0.0.1:29318";
assert bridgeSettings.appservice.hostname == "127.0.0.1";
assert bridgeSettings.appservice.port == 29318;
assert !(bridgeSettings.appservice ? public_address);
assert bridgeSettings.database.type == "postgres";
assert lib.hasInfix "mautrix-whatsapp" bridgeSettings.database.uri;
assert bridgeSettings.bridge.relay.enabled == false;
assert bridgeSettings.bridge.permissions."*" == "relay";
assert bridgeSettings.bridge.permissions.${bridgeAdmin} == "admin";
assert bridgeSettings.encryption.allow;
assert bridgeSettings.encryption.default;
assert bridgeSettings.encryption.require;
assert bridgeSettings.encryption.pickle_key == "$MAUTRIX_WHATSAPP_ENCRYPTION_PICKLE_KEY";
assert bridgeSettings.provisioning.shared_secret == "$MAUTRIX_WHATSAPP_PROVISIONING_SHARED_SECRET";
assert bridgeSettings.public_media.signing_key == "$MAUTRIX_WHATSAPP_PUBLIC_MEDIA_SIGNING_KEY";
assert bridgeSettings.direct_media.server_key == "$MAUTRIX_WHATSAPP_DIRECT_MEDIA_SERVER_KEY";
assert bridgeVolume != null;
assert bridgeVolume.image == "mautrix-whatsapp-state.img";
assert bridgeVolume.size == 10240;
assert lib.elem "/var/lib/mautrix-whatsapp/whatsapp-registration.yaml"
  vmCfg.services.matrix-synapse.settings.app_service_config_files;
assert bridgeEnvironment.owner == "mautrix-whatsapp";
assert bridgeEnvironment.group == "mautrix-whatsapp";
assert bridgeEnvironment.mode == "0400";
assert lib.all (
  name:
  let secret = vmCfg.sops.secrets.${name};
  in
  secret.owner == "root" && secret.group == "mautrix-whatsapp" && secret.mode == "0440"
) bridgeSecrets;
assert matrixInstance.portForward.enable == false;
assert matrixInstance.portForward.ports == [ ];
assert vmCfg.networking.firewall.allowedTCPPorts == [ ];
assert lib.elem "mautrix-whatsapp" synapseService.serviceConfig.SupplementaryGroups;
assert registrationService.serviceConfig.Type == "oneshot";
assert registrationService.serviceConfig.User == "mautrix-whatsapp";
assert registrationService.serviceConfig.EnvironmentFile == bridgeEnvironment.path;
assert lib.elem "matrix-synapse.service" registrationService.before;
assert lib.elem "mautrix-whatsapp-registration.service" synapseService.requires;
assert lib.elem "mautrix-whatsapp-registration.service" synapseService.after;
assert dbInitService.serviceConfig.Type == "oneshot";
assert dbInitService.serviceConfig.User == vmCfg.services.postgresql.superUser;
assert lib.elem "mautrix-whatsapp-db-init.service" bridgeService.requires;
assert lib.elem "mautrix-whatsapp-registration.service" bridgeService.requires;
assert bridgeService.serviceConfig.User == "mautrix-whatsapp";
assert bridgeService.serviceConfig.PrivateUsers == false;
assert bridgeService.serviceConfig.MemoryHigh == "512M";
assert bridgeService.serviceConfig.MemoryMax == "1G";
assert bridgeService.serviceConfig.TasksMax == 256;
assert lib.elem pkgs.ffmpeg-headless bridgeService.path;
assert lib.elem pkgs.lottieconverter bridgeService.path;
pkgs.runCommand "matrix-whatsapp-bridge-tests" { } ''
  touch "$out"
''
