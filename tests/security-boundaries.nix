{
  pkgs,
  masterPkgs ? pkgs,
}:
let
  inherit (pkgs) lib;
  python = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);
  mkService =
    name: settings: secrets:
    (import "${pkgs.path}/nixos/lib/eval-config.nix" {
      system = pkgs.stdenv.hostPlatform.system;
      modules = [
        ../modules/services/${name}.nix
        ../modules/services/traefik.nix
        ../modules/security/secrets.nix
        {
          system.stateVersion = "25.05";
          sys.services.${name} = settings;
          sys.secrets = secrets;
        }
      ];
    }).config;
  scrutiny = mkService "scrutiny" { enable = true; } {
    scrutinyTokenEnvironmentFile = "/fixture/scrutiny.env";
  };
  searx = mkService "searx" { enable = true; } {
    searxSecretKeyFile = "/fixture/searx-key";
  };
  paperless = mkService "paperless" {
    enable = true;
    secretKeyFile = "/fixture/paperless-key";
  } { };
  grafana = mkService "grafana" { enable = true; } {
    grafanaSecretKeyFile = "/fixture/grafana-key";
  };
  cloudflare =
    (import "${pkgs.path}/nixos/lib/eval-config.nix" {
      system = pkgs.stdenv.hostPlatform.system;
      modules = [
        ../modules/services/cloudflare-access-ip-updater.nix
        {
          system.stateVersion = "25.05";
          sys.services.cloudflareAccessIpUpdater = {
            enable = true;
            accountIdFile = "@@FIXTURE@@/account";
            policyIdFile = "@@FIXTURE@@/policy";
            apiTokenFile = "@@FIXTURE@@/token";
            ipService = "https://ip.fixture";
          };
        }
      ];
    }).config;
  constructorFor =
    shares:
    import ../vms/mkMicrovmConfig.nix
      {
        name = "fixture";
        cid = 100;
        mac = "02:00:00:00:00:01";
        ip = "10.100.0.2";
        mem = 256;
      }
      {
        inherit lib;
        config.microvm.shares = shares;
      };
  constructor = constructorFor [
    {
      source = "/nix/store";
      readOnly = true;
    }
  ];
  writableStore = constructorFor [
    {
      source = "/nix/store/";
      readOnly = false;
    }
  ];
  writableData = constructorFor [
    {
      source = "/data";
      readOnly = false;
    }
  ];
  storeShare = builtins.head constructor.microvm.shares;
  libvirt =
    (import "${pkgs.path}/nixos/lib/eval-config.nix" {
      system = pkgs.stdenv.hostPlatform.system;
      modules = [
        ../modules/virtualisation/libvirtd.nix
        {
          system.stateVersion = "25.05";
          sys.virtualisation.libvirtd.enable = true;
        }
      ];
    }).config;
  ml =
    imagePkgs: acceleration:
    (lib.evalModules {
      specialArgs = {
        pkgs = imagePkgs;
        consts = import ../lib/constants.nix;
      };
      modules = [
        ../containers/immich-machine-learning.nix
        {
          options = {
            home.homeDirectory = lib.mkOption {
              type = lib.types.str;
              default = "/fixture";
            };
            assertions = lib.mkOption {
              type = lib.types.listOf lib.types.attrs;
              default = [ ];
            };
            systemd.user.tmpfiles.rules = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
            };
            virtualisation.quadlet.containers = lib.mkOption {
              type = lib.types.attrs;
              default = { };
            };
          };
          config.services.immich-machine-learning-container = {
            enable = true;
            inherit acceleration;
          };
        }
      ];
    }).config;
  baseMl = ml pkgs "cpu";
  kaizerMl = ml (pkgs // { inherit (masterPkgs) immich; }) "cuda";
  imagePins = (import ../lib/oci-images.nix).immich;
  searxInit = pkgs.writeShellScript "searx-init-fixture" (
    lib.replaceStrings [ "cd /run/searx" ] [ ''cd "$SEARX_FIXTURE_DIR"'' ]
      searx.systemd.services.searx-init.script
  );
  grafanaBootstrap = pkgs.writeShellScript "grafana-bootstrap-fixture" grafana.systemd.services.grafana.preStart;
in
assert storeShare.source == "/nix/store" && storeShare.readOnly;
assert lib.all (a: a.assertion) baseMl.assertions;
assert lib.all (a: a.assertion) kaizerMl.assertions;
assert
  baseMl.virtualisation.quadlet.containers.immich-machine-learning.containerConfig.image
  == imagePins.${pkgs.immich.version}.cpu;
assert
  kaizerMl.virtualisation.quadlet.containers.immich-machine-learning.containerConfig.image
  == imagePins.${masterPkgs.immich.version}.cuda;
assert lib.any (a: !a.assertion) writableStore.assertions;
assert lib.all (a: a.assertion) writableData.assertions;
assert !(lib.elem "virbr0" libvirt.networking.firewall.trustedInterfaces);
assert libvirt.networking.firewall.interfaces.virbr0.allowedTCPPorts == [ 53 ];
assert
  libvirt.networking.firewall.interfaces.virbr0.allowedUDPPorts == [
    53
    67
  ];
assert scrutiny.services.scrutiny.settings.web.listen.host == "127.0.0.1";
assert !scrutiny.services.scrutiny.openFirewall;
assert scrutiny.services.scrutiny.collector.settings.api.endpoint == "http://127.0.0.1:8072";
assert searx.services.searx.settings.server.secret_key == "$SEARX_SECRET_KEY";
assert searx.services.searx.environmentFile == "/run/searx-secret-environment/environment";
assert lib.elem "searx-init.service" searx.systemd.services.searx-secret-environment.requiredBy;
assert !(paperless.services.paperless.settings ? PAPERLESS_SECRET_KEY);
assert
  paperless.services.paperless.environmentFile == "/run/paperless-secret-environment/environment";
assert lib.elem "paperless-secret-key.service"
  paperless.systemd.services.paperless-secret-environment.requiredBy;
assert
  grafana.services.grafana.settings.security.admin_password
  == "$__file{/var/lib/grafana/bootstrap-admin-password}";
pkgs.runCommand "security-boundaries"
  {
    nativeBuildInputs = [
      python
      pkgs.bash
    ];
  }
  ''
    mkdir -p source/lib source/tests source/home/programs/scripts
    cp ${../lib/runtime-secret-environment.py} source/lib/runtime-secret-environment.py
    cp ${../home/programs/scripts/safe-extract.py} source/home/programs/scripts/safe-extract.py
    cp ${./runtime_secret_environment_test.py} source/tests/runtime_secret_environment_test.py
    cp ${./safe_extract_test.py} source/tests/safe_extract_test.py
    cp ${./cloudflare_access_updater_test.py} source/tests/cloudflare_access_updater_test.py
    cp ${./grafana_bootstrap_test.py} source/tests/grafana_bootstrap_test.py
    export BSDTAR=${pkgs.libarchive}/bin/bsdtar
    export UPDATER_SCRIPT=${cloudflare.systemd.services.cloudflare-access-ip-updater.serviceConfig.ExecStart}
    export CURL_BIN=${pkgs.curl}/bin/curl
    export SEARX_INIT_SCRIPT=${searxInit}
    export GRAFANA_BOOTSTRAP_SCRIPT=${grafanaBootstrap}
    python3 -B -m unittest discover -s source/tests -p '*_test.py' -v
    touch "$out"
  ''
