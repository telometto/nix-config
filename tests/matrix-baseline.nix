{
  matrix,
  blizzard,
  pkgs,
}:
let
  inherit (pkgs) lib;
  vmCfg = matrix.config;
  hostCfg = blizzard.config;
  networkDefaults = import ../vms/microvm-network-defaults.nix;
  matrixRegistry = (import ../vms/vm-registry.nix)."matrix-synapse";
  matrixGateway = matrixRegistry.gateway or networkDefaults.defaultGateway;
  matrixInstance = hostCfg.sys.virtualisation.microvm.instances.matrix-synapse;
  nginxLocations = vmCfg.services.nginx.virtualHosts.matrix.locations;
  synapseListeners = vmCfg.services.matrix-synapse.settings.listeners or [ ];
  masBaseConfig = builtins.fromJSON (
    builtins.readFile vmCfg.environment.etc."matrix-authentication-service/config.json".source
  );
  masWebListener = lib.findFirst (listener: listener.name == "web") null masBaseConfig.http.listeners;
  masInternalListener = lib.findFirst (
    listener: listener.name == "internal"
  ) null masBaseConfig.http.listeners;
  firewallCommands = lib.filter (line: line != "") (
    map lib.trim (lib.splitString "\n" vmCfg.networking.firewall.extraCommands)
  );
  expectedFirewallRule = "${pkgs.iptables}/bin/iptables -A nixos-fw -i ${networkDefaults.guestInterface} -p tcp --dport ${toString matrixRegistry.port} -s ${matrixGateway} -j nixos-fw-accept";
  nginxConfig = vmCfg.environment.etc."nginx/nginx.conf".source;
  synapseService = vmCfg.systemd.services."matrix-synapse";
  synapseSecretService = vmCfg.systemd.services."matrix-synapse-secret";
  masService = vmCfg.systemd.services."matrix-authentication-service";
  masSecretService = vmCfg.systemd.services."mas-secret";
  masDbInitService = vmCfg.systemd.services."mas-db-init";
  synapseRegistrationSecret = vmCfg.sops.secrets."matrix-synapse/registration_shared_secret";
  synapseDelegationSecret = vmCfg.sops.secrets."matrix-authentication-service/synapse_secret";
  smtpSecret = vmCfg.sops.secrets."matrix-authentication-service/smtp_token";
  hasHelperHardening =
    service:
    let
      unit = service.serviceConfig;
    in
    unit.AmbientCapabilities == ""
    && unit.CapabilityBoundingSet == ""
    && unit.LockPersonality
    && unit.NoNewPrivileges
    && unit.PrivateDevices
    && unit.PrivateTmp
    && unit.ProtectClock
    && unit.ProtectControlGroups
    && unit.ProtectHome
    && unit.ProtectHostname
    && unit.ProtectKernelLogs
    && unit.ProtectKernelModules
    && unit.ProtectKernelTunables
    && unit.ProtectSystem == "strict"
    && unit.RemoveIPC
    && unit.RestrictAddressFamilies == [ "AF_UNIX" ]
    && unit.RestrictNamespaces
    && unit.RestrictRealtime
    && unit.RestrictSUIDSGID
    && unit.SystemCallArchitectures == "native";
in
assert matrixInstance.portForward.ports == [ ];
assert matrixInstance.portForward.enable == false;
assert networkDefaults.guestInterface == "ens6";
assert !(lib.elem 11060 vmCfg.networking.firewall.allowedTCPPorts);
assert lib.elem expectedFirewallRule firewallCommands;
assert synapseListeners != [ ];
assert lib.all (listener: listener.bind_addresses == [ "127.0.0.1" ]) synapseListeners;
assert masBaseConfig.http.trusted_proxies == [ "127.0.0.1/32" ];
assert masWebListener != null;
assert masInternalListener != null;
assert vmCfg.sys.services.matrix-authentication-service.openFirewall == false;
assert vmCfg.sys.services.matrix-authentication-service.bindAddress == "127.0.0.1";
assert vmCfg.sys.services.matrix-authentication-service.trustedProxies == [ "127.0.0.1/32" ];
assert vmCfg.sys.services.matrix-synapse.bindAddress == "127.0.0.1";
assert !(builtins.hasAttr "protonmail/smtp_token" vmCfg.sops.secrets);
assert smtpSecret.mode == "0440";
assert smtpSecret.owner == "mas";
assert smtpSecret.group == "mas";
assert !(builtins.hasAttr "email" vmCfg.services.matrix-synapse.settings);
assert !(lib.hasInfix "protonmail/smtp_token" synapseSecretService.script);
assert !(lib.hasInfix "smtp_pass" synapseSecretService.script);
assert lib.hasInfix smtpSecret.path masSecretService.script;
assert hasHelperHardening synapseSecretService;
assert hasHelperHardening masSecretService;
assert hasHelperHardening masDbInitService;
assert lib.elem synapseRegistrationSecret.path synapseSecretService.serviceConfig.ReadOnlyPaths;
assert lib.elem synapseDelegationSecret.path synapseSecretService.serviceConfig.ReadOnlyPaths;
assert synapseSecretService.serviceConfig.ReadWritePaths == [ "/run/matrix-synapse-secret" ];
assert lib.elem "/etc/matrix-authentication-service/config.json"
  masSecretService.serviceConfig.ReadOnlyPaths;
assert lib.elem smtpSecret.path masSecretService.serviceConfig.ReadOnlyPaths;
assert masSecretService.serviceConfig.ReadWritePaths == [ "/run/mas-secret" ];
assert masService.serviceConfig.AmbientCapabilities == "";
assert masService.serviceConfig.CapabilityBoundingSet == "";
assert masService.serviceConfig.NoNewPrivileges;
assert masService.serviceConfig.PrivateDevices;
assert masService.serviceConfig.PrivateTmp;
assert masService.serviceConfig.ProtectSystem == "strict";
assert masService.serviceConfig.ProtectHome;
assert masService.serviceConfig.ReadWritePaths == [ "/var/lib/mas" ];
assert
  masService.serviceConfig.RestrictAddressFamilies == [
    "AF_UNIX"
    "AF_INET"
    "AF_INET6"
  ];
assert masService.serviceConfig.SystemCallArchitectures == "native";
assert lib.elem "/run/mas-secret" masService.serviceConfig.ReadOnlyPaths;
assert masWebListener.binds == [ { address = "127.0.0.1:8081"; } ];
assert
  masInternalListener.binds == [
    {
      host = "127.0.0.1";
      port = 8082;
    }
  ];
assert
  vmCfg.sys.services.matrix-authentication-service.settings.account.password_registration_enabled
  == false;
assert
  vmCfg.sys.services.matrix-authentication-service.settings.account.password_recovery_enabled == true;
assert vmCfg.services.matrix-synapse.settings.enable_registration == false;
assert nginxLocations."~ ^/_synapse/admin(?:/|$)".return == "403";
assert
  nginxLocations."~ ^/_matrix/client/(r0|v1|v3)/login(/|$)".proxyPass == "http://127.0.0.1:8081";
assert
  nginxLocations."~ ^/_matrix/client/(r0|v1|v3)/logout(/all)?$".proxyPass == "http://127.0.0.1:8081";
assert nginxLocations."~ ^/_matrix/client/(r0|v1|v3)/refresh$".proxyPass == "http://127.0.0.1:8081";
assert nginxLocations."/.well-known/openid-configuration".proxyPass == "http://127.0.0.1:8081";
assert nginxLocations."/oauth2/".proxyPass == "http://127.0.0.1:8081";
assert nginxLocations."/account/".proxyPass == "http://127.0.0.1:8081";
assert nginxLocations."/.well-known/jwks.json".proxyPass == "http://127.0.0.1:8081";
assert nginxLocations."/graphql".proxyPass == "http://127.0.0.1:8081";
assert nginxLocations."/".proxyPass == "http://127.0.0.1:8008";
assert !(builtins.hasAttr "/_synapse/client/rendezvous" nginxLocations);
assert nginxLocations."= /.well-known/matrix/server".return != null;
assert nginxLocations."= /.well-known/matrix/client".return != null;
assert nginxLocations."= /.well-known/matrix/support".return != null;
assert lib.hasInfix "add_header Access-Control-Allow-Origin *"
  nginxLocations."= /.well-known/matrix/server".extraConfig;
assert lib.hasInfix "add_header Access-Control-Allow-Origin *"
  nginxLocations."= /.well-known/matrix/client".extraConfig;
assert lib.hasInfix "add_header Access-Control-Allow-Origin *"
  nginxLocations."= /.well-known/matrix/support".extraConfig;
assert
  !(builtins.hasAttr "Access-Control-Allow-Origin" hostCfg.services.traefik.dynamic.files.core.settings.http.middlewares.matrix-headers.headers.customResponseHeaders);
assert lib.elem "sops-install-secrets.service" synapseService.after;
assert lib.elem "sops-install-secrets.service" synapseService.requires;
assert lib.elem "matrix-synapse.service" synapseSecretService.before;
assert lib.elem "matrix-synapse.service" synapseSecretService.requiredBy;
assert lib.elem "sops-install-secrets.service" synapseSecretService.after;
assert lib.elem "sops-install-secrets.service" synapseSecretService.requires;
assert lib.elem "sops-install-secrets.service" masService.after;
assert lib.elem "sops-install-secrets.service" masService.requires;
assert lib.elem "matrix-authentication-service.service" masSecretService.before;
assert lib.elem "matrix-authentication-service.service" masSecretService.requiredBy;
assert lib.elem "sops-install-secrets.service" masSecretService.after;
assert lib.elem "sops-install-secrets.service" masSecretService.requires;
pkgs.runCommand "matrix-baseline-tests"
  {
    inherit nginxConfig;
    nativeBuildInputs = [ pkgs.gnugrep ];
  }
  ''
    grep -F -- 'location ~ ^/_synapse/admin(?:/|$)' "$nginxConfig"
    grep -F -- 'return 403;' "$nginxConfig"
    grep -F -- 'location ~ ^/_matrix/client/(r0|v1|v3)/login(/|$)' "$nginxConfig"
    grep -F -- 'location ~ ^/_matrix/client/(r0|v1|v3)/logout(/all)?$' "$nginxConfig"
    grep -F -- 'location ~ ^/_matrix/client/(r0|v1|v3)/refresh$' "$nginxConfig"
    grep -F -- 'proxy_pass http://127.0.0.1:8081;' "$nginxConfig"
    grep -F -- 'proxy_pass http://127.0.0.1:8008;' "$nginxConfig"
    grep -F -- 'location / {' "$nginxConfig"
    touch "$out"
  ''
