{
  matrix,
  blizzard,
  pkgs,
  ...
}:
let
  inherit (pkgs) lib;
  vmCfg = matrix.config;
  hostCfg = blizzard.config;
  traefikLib = import ../lib/traefik.nix { inherit lib; };
  inherit (traefikLib) matrixRoutes;
  proxyPassByTarget = {
    mas = "http://127.0.0.1:8081";
    synapse = "http://127.0.0.1:8008";
  };
  alternateRuntimeConfigFile = "/run/mas-alternate/config.json";
  alternateRuntimeConfig = matrix.extendModules {
    modules = [
      {
        sys.services.matrix-authentication-service.runtimeConfigFile = lib.mkForce alternateRuntimeConfigFile;
      }
    ];
  };
  defaultRuntimeConfig = matrix.extendModules {
    modules = [
      {
        sys.services.matrix-authentication-service.runtimeConfigFile = lib.mkForce null;
      }
    ];
  };
  relativeRuntimeConfig = matrix.extendModules {
    modules = [
      {
        sys.services.matrix-authentication-service.runtimeConfigFile = lib.mkForce "relative/config.json";
      }
    ];
  };
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
  alternateMasService =
    alternateRuntimeConfig.config.systemd.services."matrix-authentication-service";
  alternateMasSecretService = alternateRuntimeConfig.config.systemd.services."mas-secret";
  defaultMasService = defaultRuntimeConfig.config.systemd.services."matrix-authentication-service";
  defaultBaseConfigFile =
    defaultRuntimeConfig.config.environment.etc."matrix-authentication-service/config.json".source;
  synapseRegistrationSecret = vmCfg.sops.secrets."matrix-synapse/registration_shared_secret";
  synapseDelegationSecret = vmCfg.sops.secrets."matrix-authentication-service/synapse_secret";
  smtpSecret = vmCfg.sops.secrets."matrix-authentication-service/smtp_token";
  routeContractPasses =
    route:
    let
      location = nginxLocations.${route.location};
    in
    if route.target == "deny" then
      location.return == "403"
    else
      location.proxyPass == proxyPassByTarget.${route.target};
  wellKnownContractPasses = route: nginxLocations.${route.location}.return != null;
  hasFailedAssertion =
    message: cfg:
    lib.any (assertion: !assertion.assertion && lib.hasInfix message assertion.message) cfg.assertions;
  routeProbeCommands = lib.concatMapStringsSep "\n" (
    route:
    let
      matches = map (path: "check_route ${lib.escapeShellArg path} ${route.target}") route.matches;
      rejects = map (path: "check_route ${lib.escapeShellArg path} synapse") route.rejects;
    in
    lib.concatStringsSep "\n" (matches ++ rejects)
  ) matrixRoutes.routeContracts;
  wellKnownProbeCommands = lib.concatMapStringsSep "\n" (
    route: "check_well_known ${lib.escapeShellArg route.path} ${lib.escapeShellArg route.marker}"
  ) matrixRoutes.wellKnownContracts;
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
assert lib.all routeContractPasses matrixRoutes.routeContracts;
assert lib.all wellKnownContractPasses matrixRoutes.wellKnownContracts;
assert lib.hasInfix alternateRuntimeConfigFile alternateMasService.serviceConfig.ExecStart;
assert lib.hasInfix alternateRuntimeConfigFile alternateMasSecretService.script;
assert alternateMasSecretService.serviceConfig.RuntimeDirectory == "mas-alternate";
assert alternateMasSecretService.serviceConfig.ReadWritePaths == [ "/run/mas-alternate" ];
assert lib.elem "/run/mas-alternate" alternateMasService.serviceConfig.ReadOnlyPaths;
assert
  defaultMasService.serviceConfig.ExecStart
  == "${pkgs.matrix-authentication-service}/bin/mas-cli server --config ${defaultBaseConfigFile}";
assert !(lib.elem "/run/mas-secret" defaultMasService.serviceConfig.ReadOnlyPaths);
assert hasFailedAssertion "runtimeConfigFile must be an absolute path" relativeRuntimeConfig.config;
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
assert !(builtins.hasAttr "/_synapse/client/rendezvous" nginxLocations);
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
    inherit nginxConfig routeProbeCommands wellKnownProbeCommands;
    nativeBuildInputs = [
      pkgs.curl
      pkgs.gnugrep
      pkgs.nginx
      pkgs.python3
    ];
  }
  ''
    set -euo pipefail

    testConfig="$TMPDIR/nginx.conf"
    sed \
      -e "s#pid /run/nginx/nginx.pid;#pid $TMPDIR/nginx.pid;#" \
      -e "s#listen 0.0.0.0:11060 *;#listen 127.0.0.1:18080;#" \
      -e "s#listen 11060 *;#listen 127.0.0.1:18080;#" \
      -e "s#127.0.0.1:8081#127.0.0.1:18081#g" \
      -e "s#127.0.0.1:8008#127.0.0.1:18008#g" \
      -e 's#http {#http {\n\taccess_log off;#' \
      "$nginxConfig" > "$testConfig"
    ${pkgs.nginx}/bin/nginx -t -e stderr -c "$testConfig"

    masPid=""
    synapsePid=""
    nginxPid=""
    cleanup() {
      kill "$nginxPid" "$masPid" "$synapsePid" 2>/dev/null || true
      wait "$nginxPid" "$masPid" "$synapsePid" 2>/dev/null || true
    }
    trap cleanup EXIT

    ${pkgs.python3}/bin/python -c 'import sys; from http.server import BaseHTTPRequestHandler, HTTPServer; Handler = type("Handler", (BaseHTTPRequestHandler,), {"do_GET": lambda self: (self.send_response(200), self.end_headers(), self.wfile.write(sys.argv[2].encode())), "log_message": lambda self, *args: None}); HTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()' 18081 mas &
    masPid=$!
    ${pkgs.python3}/bin/python -c 'import sys; from http.server import BaseHTTPRequestHandler, HTTPServer; Handler = type("Handler", (BaseHTTPRequestHandler,), {"do_GET": lambda self: (self.send_response(200), self.end_headers(), self.wfile.write(sys.argv[2].encode())), "log_message": lambda self, *args: None}); HTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()' 18008 synapse &
    synapsePid=$!
    ${pkgs.nginx}/bin/nginx -e stderr -c "$testConfig" &
    nginxPid=$!

    for attempt in $(seq 1 50); do
      if ${pkgs.curl}/bin/curl --fail --silent --show-error http://127.0.0.1:18080/not-a-mas-route >/dev/null 2>&1; then
        break
      fi
      sleep 0.1
    done

    check_route() {
      local path="$1"
      local expected="$2"
      case "$expected" in
        mas|synapse)
          body="$(${pkgs.curl}/bin/curl --fail --silent --show-error "http://127.0.0.1:18080''${path}")"
          test "$body" = "$expected"
          ;;
        deny)
          status="$(${pkgs.curl}/bin/curl --silent --show-error --output /dev/null --write-out '%{http_code}' "http://127.0.0.1:18080''${path}")"
          test "$status" = "403"
          ;;
        *)
          echo "unknown expected route target: $expected" >&2
          return 1
          ;;
      esac
    }

    check_well_known() {
      local path="$1"
      local marker="$2"
      body="$(${pkgs.curl}/bin/curl --fail --silent --show-error "http://127.0.0.1:18080''${path}")"
      printf '%s' "$body" | grep -F -- "$marker" >/dev/null
    }

    ${routeProbeCommands}
    ${wellKnownProbeCommands}
    touch "$out"
  ''
