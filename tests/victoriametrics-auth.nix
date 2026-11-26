# Public-only fixture; no private flake or real password files are evaluated.
{ pkgs }:
let
  inherit (pkgs) lib;
  consts = import ../lib/constants.nix;
  evaluate =
    settings:
    (import "${pkgs.path}/nixos/lib/eval-config.nix" {
      system = pkgs.stdenv.hostPlatform.system;
      specialArgs = { inherit consts; };
      modules = [
        ../modules/services/victoriametrics.nix
        {
          # Keep this fixture focused on the metrics module's client contract.
          options.sys.services.grafana = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
            };
            provision = {
              datasources = lib.mkOption {
                type = lib.types.listOf lib.types.attrs;
                default = [ ];
              };
              deleteDatasources = lib.mkOption {
                type = lib.types.listOf lib.types.attrs;
                default = [ ];
              };
            };
          };
          config = {
            system.stateVersion = "25.05";
            networking.hostName = "metrics-fixture";
            services.prometheus.enable = true;
            services.grafana.enable = true;
            sys.services.victoriametrics = lib.recursiveUpdate {
              enable = true;
              port = 11008;
              listenAddress = "192.0.2.1";
              httpAuth = {
                username = "metrics-writer";
                passwordFile = "/fixture/writer-password";
              };
              authorization = {
                enable = true;
                queryPasswordFile = "/fixture/query-password";
                backendPasswordFile = "/fixture/backend-password";
              };
            } settings;
          };
        }
      ];
    }).config;
  authorized = evaluate { };
  legacy = evaluate { authorization.enable = false; };
  loopback = evaluate {
    listenAddress = "127.0.0.1";
    authorization.enable = false;
    httpAuth = {
      username = null;
      passwordFile = null;
    };
  };
  runtime = evaluate {
    httpAuth.username = "writer";
    authorization = {
      queryUsername = "reader";
      backendUsername = "backend";
    };
  };
  validAssertions =
    settings:
    lib.all (a: a.assertion)
      (import ../modules/services/victoriametrics.nix {
        inherit pkgs lib consts;
        config.sys.services.victoriametrics = lib.recursiveUpdate authorized.sys.services.victoriametrics settings;
      }).config.content.assertions;
  vm = authorized.services.victoriametrics;
  vmUnit = authorized.systemd.services.victoriametrics;
  frontend = authorized.systemd.services.victoriametrics-vmauth;
  datasource = builtins.head authorized.sys.services.grafana.provision.datasources;
  remoteWrite = builtins.head authorized.services.prometheus.remoteWrite;
in
assert validAssertions { };
assert lib.all (address: !validAssertions { listenAddress = address; }) [
  "0.0.0.0"
  "127.0.0.1"
  "127.0.0.2"
  "::"
  "::1"
  "localhost"
  "metrics.example"
  "256.0.0.1"
];
assert !validAssertions { httpAuth.username = ""; };
assert !validAssertions { authorization.queryPasswordFile = null; };
assert !validAssertions { authorization.backendPasswordFile = null; };
assert !validAssertions { authorization.queryUsername = "metrics-writer"; };
assert !validAssertions { authorization.backendUsername = "metrics-query"; };
assert !validAssertions { authorization.queryUsername = "bad:name"; };
assert !validAssertions { prometheusRemoteWrite.path = "/api/v1/import"; };
assert !validAssertions { extraOptions = [ "--httpListenAddr=0.0.0.0:11008" ]; };
assert
  !validAssertions {
    extraOptions = [
      "-httpAuth.password"
      "unsafe"
    ];
  };
assert vm.listenAddress == "127.0.0.1:11008";
assert vm.basicAuthUsername == "metrics-backend";
assert vm.basicAuthPasswordFile == "/fixture/backend-password";
assert builtins.length vmUnit.serviceConfig.LoadCredential == 3;
assert lib.all (credential: lib.elem credential vmUnit.serviceConfig.LoadCredential) [
  "basic_auth_password:/fixture/backend-password"
  "writer-password:/fixture/writer-password"
  "query-password:/fixture/query-password"
];
assert lib.hasInfix "validate-password" vmUnit.preStart;
assert
  frontend.serviceConfig.LoadCredential == [
    "writer-password:/fixture/writer-password"
    "query-password:/fixture/query-password"
    "backend-password:/fixture/backend-password"
  ];
assert frontend.serviceConfig.DynamicUser;
assert frontend.serviceConfig.RuntimeDirectoryMode == "0700";
assert frontend.serviceConfig.UMask == "0077";
assert frontend.serviceConfig.ProtectSystem == "strict";
assert lib.hasInfix "-httpListenAddr=192.0.2.1:11008" frontend.serviceConfig.ExecStart;
assert lib.hasInfix "-httpInternalListenAddr=unix:/run/victoriametrics-vmauth/internal.sock"
  frontend.serviceConfig.ExecStart;
assert lib.elem "victoriametrics.service" frontend.after;
assert lib.elem "victoriametrics.service" frontend.requires;
assert lib.elem "victoriametrics.service" frontend.partOf;
assert lib.elem "sops-install-secrets.service" frontend.after;
assert remoteWrite.url == "http://192.0.2.1:11008/api/v1/write";
assert remoteWrite.basic_auth.username == "metrics-writer";
assert remoteWrite.basic_auth.password_file == "/fixture/writer-password";
assert lib.elem "monitoring-credentials" authorized.users.users.prometheus.extraGroups;
assert !(lib.elem "monitoring-credentials" authorized.users.users.grafana.extraGroups);
assert datasource.url == "http://192.0.2.1:11008";
assert datasource.basicAuthUser == "metrics-query";
assert
  datasource.secureJsonData.basicAuthPassword
  == "$__file{/run/credentials/grafana.service/victoriametrics-query-password}";
assert
  authorized.systemd.services.grafana.serviceConfig.LoadCredential == [
    "victoriametrics-query-password:/fixture/query-password"
  ];
assert !(legacy.systemd.services ? victoriametrics-vmauth);
assert legacy.services.victoriametrics.listenAddress == "192.0.2.1:11008";
assert legacy.services.victoriametrics.basicAuthUsername == "metrics-writer";
assert lib.elem "monitoring-credentials" legacy.users.users.grafana.extraGroups;
assert !(loopback.systemd.services ? victoriametrics-vmauth);
assert loopback.services.victoriametrics.basicAuthUsername == null;
assert loopback.services.victoriametrics.basicAuthPasswordFile == null;
pkgs.runCommand "victoriametrics-auth-tests"
  {
    nativeBuildInputs = [ pkgs.python3 ];
    VMAUTH_BINARY = "${pkgs.victoriametrics}/bin/vmauth";
    VICTORIAMETRICS_AUTH_RENDERER = ../lib/victoriametrics-auth.py;
    VICTORIAMETRICS_AUTH_PRESTART = pkgs.writeText "vmauth-prestart-fixture" runtime.systemd.services.victoriametrics-vmauth.preStart;
    VICTORIAMETRICS_BACKEND_PRESTART = pkgs.writeText "victoriametrics-prestart-fixture" runtime.systemd.services.victoriametrics.preStart;
  }
  ''
    export PYTHONDONTWRITEBYTECODE=1
    ${pkgs.python3}/bin/python3 ${./victoriametrics_auth_test.py} -v
    touch "$out"
  ''
