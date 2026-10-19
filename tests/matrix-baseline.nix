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
  consts = import ../lib/constants.nix;
  matrixRegistry = (import ../vms/vm-registry.nix { inherit consts; })."matrix-synapse";
  matrixGateway = matrixRegistry.gateway or networkDefaults.defaultGateway;
  matrixInstance = hostCfg.sys.virtualisation.microvm.instances.matrix-synapse;
  nginxLocations = vmCfg.services.nginx.virtualHosts.matrix.locations;
  proxyRouteContracts = lib.filter (route: route.target != "deny") matrixRoutes.routeContracts;
  proxyLocationNames = builtins.attrNames (
    lib.filterAttrs (_: location: location.proxyPass != null) nginxLocations
  );
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
assert networkDefaults.guestInterface == "microvm0";
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
assert lib.all (route: route.matches != [ ]) matrixRoutes.routeContracts;
assert
  lib.sort builtins.lessThan (map (route: route.location) proxyRouteContracts) == proxyLocationNames;
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

    curl() {
      ${pkgs.curl}/bin/curl --connect-timeout 1 --max-time 3 --noproxy '*' "$@"
    }

    backendPid=""
    nginxPid=""
    cleanup() {
      local status=$? pid log
      for pid in "$nginxPid" "$backendPid"; do
        if test -n "$pid"; then kill "$pid" 2>/dev/null || true; fi
      done
      for pid in "$nginxPid" "$backendPid"; do
        if test -n "$pid"; then wait "$pid" 2>/dev/null || true; fi
      done
      if test "$status" != 0; then
        for log in "$TMPDIR/backend.log" "$TMPDIR/nginx.log"; do
          if test -f "$log"; then cat "$log" >&2; fi
        done
      fi
    }
    trap cleanup EXIT

    ${pkgs.python3}/bin/python - <<'PY' >"$TMPDIR/backend.log" 2>&1 &
    import json
    import os
    import secrets
    import socket
    from http.server import BaseHTTPRequestHandler, HTTPServer
    from pathlib import Path
    from threading import Thread
    from urllib.parse import urlsplit

    session_path = "/_synapse/client/rendezvous/test-session"
    creation_path = "/_matrix/client/unstable/org.matrix.msc4108/rendezvous"
    fixture_id = secrets.token_hex(16)

    class Handler(BaseHTTPRequestHandler):
        def synapse_only(self):
            path = urlsplit(self.path).path
            rendezvous = (path == "/_synapse/client/rendezvous" or
                          path.startswith("/_synapse/client/rendezvous/") or
                          path == creation_path)
            if rendezvous and self.server.target != "synapse":
                self.send_error(404)
                return True
            return False

        def respond(self, status, body=b"", content_type="text/plain", etag=False):
            self.send_response(status)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("X-Fixture-Backend", self.server.target)
            if etag:
                self.send_header("ETag", '"rendezvous-fixture"')
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            if self.synapse_only():
                return
            request = urlsplit(self.path)
            rendezvous = request.path == session_path
            body = b"rendezvous payload " * 128 if rendezvous else self.server.target.encode()
            if request.query == "fixture-ready=1":
                body = f"{self.server.target}|{fixture_id}".encode()
            elif request.query == "client-ip-check=1":
                body = "|".join(",".join(self.headers.get_all(h, [])) for h in
                                ("X-Forwarded-For", "X-Real-IP")).encode()
            self.respond(200, body, etag=rendezvous)

        def do_POST(self):
            if self.synapse_only():
                return
            if urlsplit(self.path).path != creation_path:
                self.send_error(404)
                return
            self.rfile.read(int(self.headers.get("Content-Length", "0")))
            body = json.dumps({"url": f"https://matrix.example{session_path}"}).encode()
            self.respond(201, body, "application/json", etag=True)

        def do_PUT(self):
            if self.synapse_only():
                return
            if urlsplit(self.path).path != session_path:
                self.send_error(404)
                return
            self.rfile.read(int(self.headers.get("Content-Length", "0")))
            matches = self.headers.get("If-Match") == '"rendezvous-fixture"'
            self.respond(202 if matches else 412)

        def log_message(self, *args):
            pass

    # Hold both backend sockets for the process lifetime. The proxy candidate
    # is released for Nginx; liveness and a per-run token detect bind races.
    mas = HTTPServer(("127.0.0.1", 0), Handler)
    mas.target = "mas"
    synapse = HTTPServer(("127.0.0.1", 0), Handler)
    synapse.target = "synapse"
    with socket.socket() as proxy:
        proxy.bind(("127.0.0.1", 0))
        proxy_port = proxy.getsockname()[1]
    ports = Path(os.environ["TMPDIR"]) / "fixture.ports"
    temporary = ports.with_suffix(".tmp")
    temporary.write_text(f"{mas.server_port} {synapse.server_port} {proxy_port} {fixture_id}\n")
    temporary.replace(ports)
    Thread(target=mas.serve_forever, daemon=True).start()
    synapse.serve_forever()
    PY
    backendPid=$!

    for attempt in $(seq 1 50); do
      if ! kill -0 "$backendPid" 2>/dev/null; then
        echo "Matrix fixture backends exited during startup" >&2
        exit 1
      fi
      if test -s "$TMPDIR/fixture.ports"; then break; fi
      sleep 0.1
    done
    if ! test -s "$TMPDIR/fixture.ports"; then
      echo "Matrix fixture backends did not publish their ports" >&2
      exit 1
    fi
    read -r masPort synapsePort proxyPort fixtureId < "$TMPDIR/fixture.ports"
    proxyUrl="http://127.0.0.1:$proxyPort"

    testConfig="$TMPDIR/nginx.conf"
    sed \
      -e "s#pid /run/nginx/nginx.pid;#pid $TMPDIR/nginx.pid;#" \
      -e "s#listen 0.0.0.0:${toString matrixRegistry.port} *;#listen 127.0.0.1:$proxyPort;#" \
      -e "s#listen ${toString matrixRegistry.port} *;#listen 127.0.0.1:$proxyPort;#" \
      -e "s#127.0.0.1:8081#127.0.0.1:$masPort#g" \
      -e "s#127.0.0.1:8008#127.0.0.1:$synapsePort#g" \
      -e 's#http {#http {\n\taccess_log off;#' \
      "$nginxConfig" > "$testConfig"
    ${pkgs.nginx}/bin/nginx -t -e stderr -c "$testConfig"
    ${pkgs.nginx}/bin/nginx -e stderr -c "$testConfig" >"$TMPDIR/nginx.log" 2>&1 &
    nginxPid=$!

    ready=false
    deadline=$((SECONDS + 10))
    while (( SECONDS < deadline )); do
      if ! kill -0 "$backendPid" 2>/dev/null || ! kill -0 "$nginxPid" 2>/dev/null; then
        echo "Matrix fixture process exited before readiness" >&2
        exit 1
      fi
      masReady="$(curl --max-time 1 --fail --silent "$proxyUrl/login?fixture-ready=1")" || masReady=""
      synapseReady="$(curl --max-time 1 --fail --silent "$proxyUrl/not-a-mas-route?fixture-ready=1")" || synapseReady=""
      if test "$masReady" = "mas|$fixtureId" && test "$synapseReady" = "synapse|$fixtureId"; then
        ready=true
        break
      fi
      sleep 0.1
    done
    if test "$ready" != true; then
      echo "Matrix fixture did not become ready within 10 seconds" >&2
      exit 1
    fi

    check_route() {
      local path="$1" expected="$2" target status
      case "$expected" in
        mas|synapse)
          curl --fail --silent --show-error -D "$TMPDIR/route-headers" \
            --output /dev/null "$proxyUrl$path"
          target="$(sed -n 's/^X-Fixture-Backend: *\(.*\)\r$/\1/p' "$TMPDIR/route-headers")"
          if test "$target" != "$expected"; then
            printf 'route %s: expected %s, got %q\n' "$path" "$expected" "$target" >&2
            return 1
          fi
          ;;
        deny)
          status="$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' "$proxyUrl$path")"
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
      body="$(curl --fail --silent --show-error "$proxyUrl$path")"
      printf '%s' "$body" | grep -F -- "$marker" >/dev/null
    }

    ${routeProbeCommands}
    ${wellKnownProbeCommands}

    # Exercise every backend route, including both rendezvous locations.
    # Loopback models the trusted host proxy; 127.0.0.2 is an untrusted peer.
    check_client_ip() {
      local path="$1" source="$2" chain="$3" expected="$4"
      body="$(curl --fail --silent --show-error \
        --interface "$source" -H "X-Forwarded-For: $chain" \
        -H 'X-Real-IP: 198.51.100.9' \
        "$proxyUrl$path?client-ip-check=1")"
      test "$body" = "$expected|$expected"
    }
    for path in ${
      lib.concatMapStringsSep " " (
        route: lib.concatMapStringsSep " " lib.escapeShellArg route.matches
      ) proxyRouteContracts
    }; do
      check_client_ip "$path" 127.0.0.1 '84.234.219.121, ::1' 84.234.219.121
      check_client_ip "$path" 127.0.0.1 '203.0.113.9, 84.234.219.121, ::1, ${matrixGateway}' 84.234.219.121
      check_client_ip "$path" 127.0.0.1 '203.0.113.9, 2a01:799::123, ::1' 2a01:799::123
      check_client_ip "$path" 127.0.0.2 '203.0.113.9, ::1' 127.0.0.2
      check_client_ip "$path" 127.0.0.1 "" 127.0.0.1
      body="$(curl --fail --silent --show-error \
        -H 'X-Forwarded-For: 203.0.113.9' \
        -H 'X-Forwarded-For: 84.234.219.121, ::1' \
        "$proxyUrl$path?client-ip-check=1")"
      test "$body" = '84.234.219.121|84.234.219.121'
    done

    # Creation is a POST to the Matrix unstable endpoint, not the bare
    # /_synapse/client/rendezvous route. Keep this mock limited to proxy behavior.
    status="$(curl --silent --show-error -H 'Accept-Encoding: gzip' \
      -H 'Content-Type: text/plain' --data-binary 'initial payload' \
      -D "$TMPDIR/creation-headers" -o "$TMPDIR/creation-body" \
      --write-out '%{http_code}' \
      "$proxyUrl/_matrix/client/unstable/org.matrix.msc4108/rendezvous")"
    test "$status" = "201"
    etag="$(sed -n 's/^[Ee][Tt][Aa][Gg]: *\(.*\)\r$/\1/p' "$TMPDIR/creation-headers")"
    test "$etag" = '"rendezvous-fixture"'
    rendezvousPath="$(${pkgs.python3}/bin/python - "$TMPDIR/creation-body" <<'PY'
    import json
    import sys
    from urllib.parse import urlsplit

    with open(sys.argv[1]) as response:
        path = urlsplit(json.load(response)["url"]).path
    assert path == "/_synapse/client/rendezvous/test-session", path
    print(path)
    PY
    )"

    # Request compression as a browser would, then reuse the received ETag.
    # A gzip-weakened ETag makes the conditional PUT fail with HTTP 412.
    rendezvousUrl="$proxyUrl$rendezvousPath"
    curl --fail --silent --show-error \
      -H 'Accept-Encoding: gzip' -D "$TMPDIR/rendezvous-headers" \
      -o /dev/null "$rendezvousUrl"
    etag="$(sed -n 's/^[Ee][Tt][Aa][Gg]: *\(.*\)\r$/\1/p' "$TMPDIR/rendezvous-headers")"
    test "$etag" = '"rendezvous-fixture"'
    status="$(curl --silent --show-error \
      -X PUT -H "If-Match: $etag" -H 'Content-Type: text/plain' \
      --data-binary 'updated payload' --output /dev/null \
      --write-out '%{http_code}' "$rendezvousUrl")"
    test "$status" = "202"
    status="$(curl --silent --show-error \
      -X PUT -H "If-Match: W/$etag" -H 'Content-Type: text/plain' \
      --data-binary 'updated payload' --output /dev/null \
      --write-out '%{http_code}' "$rendezvousUrl")"
    test "$status" = "412"
    touch "$out"
  ''
