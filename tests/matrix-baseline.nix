{
  matrix,
  blizzard,
  pkgs,
}:
let
  inherit (pkgs) lib;
  vmCfg = matrix.config;
  hostCfg = blizzard.config;
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
  loginPattern = "^/_matrix/client/(r0|v1|v3)/login(/.*)?$";
  logoutPattern = "^/_matrix/client/(r0|v1|v3)/logout(/all)?$";
  refreshPattern = "^/_matrix/client/(r0|v1|v3)/refresh$";
  adminPath = path: path == "/_synapse/admin" || lib.hasPrefix "/_synapse/admin/" path;
in
assert matrixInstance.portForward.ports == [ ];
assert matrixInstance.portForward.enable == false;
assert !(lib.elem 11060 vmCfg.networking.firewall.allowedTCPPorts);
assert lib.hasInfix "--dport 11060 -s 10.100.0.1 -j nixos-fw-accept"
  vmCfg.networking.firewall.extraCommands;
assert synapseListeners != [ ];
assert lib.all (listener: listener.bind_addresses == [ "127.0.0.1" ]) synapseListeners;
assert masBaseConfig.http.trusted_proxies == [ "127.0.0.1/32" ];
assert masWebListener != null;
assert masInternalListener != null;
assert vmCfg.sys.services.matrix-authentication-service.openFirewall == false;
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
assert !(adminPath "/_synapse/client/rendezvous");
assert adminPath "/_synapse/admin";
assert adminPath "/_synapse/admin/v1/users";
assert !(adminPath "/_synapse/administrator");
assert builtins.match loginPattern "/_matrix/client/v3/login" != null;
assert builtins.match loginPattern "/_matrix/client/v3/login/sso/redirect" != null;
assert builtins.match loginPattern "/_matrix/client/v3/loginXYZ" == null;
assert builtins.match logoutPattern "/_matrix/client/v3/logout" != null;
assert builtins.match logoutPattern "/_matrix/client/v3/logout/all" != null;
assert builtins.match logoutPattern "/_matrix/client/v3/logout/all/extra" == null;
assert builtins.match refreshPattern "/_matrix/client/v3/refresh" != null;
assert builtins.match refreshPattern "/_matrix/client/v3/refresh/extra" == null;
assert
  !(builtins.hasAttr "Access-Control-Allow-Origin" hostCfg.services.traefik.dynamic.files.core.settings.http.middlewares.matrix-headers.headers.customResponseHeaders);
pkgs.runCommand "matrix-baseline-tests" { } "touch $out"
