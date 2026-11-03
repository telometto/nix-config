{
  inputs,
  system,
  pkgs,
  configurations,
  blizzard,
}:
let
  inherit (pkgs) lib;
  names = [
    "sonarr"
    "radarr"
    "lidarr"
    "readarr"
    "bazarr"
    "prowlarr"
  ];
  media = import ../vms/media-storage.nix;
  mkArr =
    name: settings:
    (inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ../modules/services/${name}.nix
        ../modules/services/traefik.nix
        {
          system.stateVersion = "25.05";
          sys.services.traefik.enable = true;
          sys.services.${name} = settings;
        }
      ];
    }).config;
  arrContract =
    name:
    let
      guest = configurations."${name}-vm".config;
      cfg = mkArr name {
        enable = true;
        port = 15000;
        dataDir = "/srv/arr-test";
        openFirewall = true;
        reverseProxy.domain = "${name}.example.test";
      };
      disabled = mkArr name { enable = false; };
      upstreamPort =
        if name == "bazarr" then
          cfg.services.bazarr.listenPort
        else
          cfg.services.${name}.settings.server.port;
      state = lib.findFirst (v: v.image == "${name}-state.img") null guest.microvm.volumes;
      mediaShares = lib.filter (s: s.tag == "media-data") guest.microvm.shares;
      exporter = guest.sys.services.arrExporter.${name};
    in
    upstreamPort == 15000
    && cfg.services.${name}.dataDir == "/srv/arr-test"
    && lib.elem 15000 cfg.networking.firewall.allowedTCPPorts
    &&
      cfg.services.traefik.dynamicConfigOptions.http.services.${name}.loadBalancer.servers
      == [ { url = "http://localhost:15000"; } ]
    && !cfg.systemd.services.${name}.serviceConfig.DynamicUser
    && cfg.systemd.services.${name}.serviceConfig.UMask == "002"
    && lib.elem "users" cfg.systemd.services.${name}.serviceConfig.SupplementaryGroups
    && !disabled.services.${name}.enable
    && !(disabled.systemd.services ? ${name})
    && state.mountPoint == "/var/lib/${name}"
    && state.size == 10240
    && (
      if name == "prowlarr" then
        mediaShares == [ ] && guest.services.flaresolverr.enable
      else
        builtins.length mediaShares == 1
        && (builtins.head mediaShares).source == media.hostPath
        && !(builtins.head mediaShares).readOnly
    )
    && exporter.enable
    && exporter.openFirewall
    && exporter.arrPort == guest.sys.services.${name}.port
    &&
      exporter.configFile
      == "/var/lib/${name}/${if name == "bazarr" then "config/config.ini" else "config.xml"}"
    &&
      (exporter.extraEnvironment.ENABLE_ADDITIONAL_METRICS or "false") == (
        if
          lib.elem name [
            "sonarr"
            "bazarr"
            "prowlarr"
          ]
        then
          "true"
        else
          "false"
      );

  mkBrowser =
    name: settings:
    (inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        inputs.quadlet-nix.nixosModules.quadlet
        ../modules/services/${name}.nix
        {
          system.stateVersion = "25.05";
          sys.services.${name} = settings;
        }
      ];
    }).config;
  browserFailures =
    name: cfg:
    lib.filter (a: !a.assertion && lib.hasPrefix "sys.services.${name}" a.message) cfg.assertions;
  browserContract =
    name:
    let
      disabled = mkBrowser name { };
      host = mkBrowser name {
        enable = true;
        httpPort = 13000;
        httpsPort = 13001;
        openFirewall = true;
      };
      bridge = mkBrowser name {
        enable = true;
        networkMode = "bridge";
        httpPort = 13000;
        httpsPort = 13001;
        enableDri = true;
        driNode = "/dev/dri/renderD128";
      };
      hc = host.virtualisation.quadlet.containers.${name}.containerConfig;
      bc = bridge.virtualisation.quadlet.containers.${name}.containerConfig;
      halfUser = mkBrowser name {
        enable = true;
        customUserFile = "/fixture/user";
      };
      halfPassword = mkBrowser name {
        enable = true;
        passwordFile = "/fixture/password";
      };
    in
    disabled.virtualisation.quadlet.containers == { }
    && !(disabled.systemd.services ? ${name})
    && hc.networks == [ "host" ]
    && hc.publishPorts == [ ]
    && hc.environments.CUSTOM_PORT == "13000"
    && hc.environments.CUSTOM_HTTPS_PORT == "13001"
    && lib.elem 13000 host.networking.firewall.allowedTCPPorts
    && lib.elem 13001 host.networking.firewall.allowedTCPPorts
    && hc.environmentFiles == [ ]
    && !(host.systemd.services.${name}.serviceConfig ? RuntimeDirectory)
    && bc.networks == [ ]
    &&
      bc.publishPorts == [
        "13000:3000"
        "13001:3001"
      ]
    && !(bc.environments ? CUSTOM_PORT)
    && !(bc.environments ? CUSTOM_HTTPS_PORT)
    && bc.devices == [ "/dev/dri" ]
    && bc.environments.DRINODE == "/dev/dri/renderD128"
    && browserFailures name host == [ ]
    && browserFailures name halfUser != [ ]
    && browserFailures name halfPassword != [ ];
  credentials = lib.genAttrs [ "brave" "firefox" ] (
    name:
    let
      cfg = mkBrowser name {
        enable = true;
        customUserFile = "/fixture/user";
        passwordFile = "/fixture/password";
      };
      unit = cfg.systemd.services.${name};
    in
    assert browserFailures name cfg == [ ];
    assert
      lib.elem "sops-install-secrets.service" unit.after
      && lib.elem "sops-install-secrets.service" unit.requires;
    assert unit.serviceConfig.RuntimeDirectoryMode == "0700";
    assert lib.hasPrefix "+" (builtins.head unit.serviceConfig.ExecStartPre);
    assert
      cfg.virtualisation.quadlet.containers.${name}.containerConfig.environmentFiles
      == [ "/run/${name}/credentials.env" ];
    {
      script = lib.removePrefix "+" (builtins.head unit.serviceConfig.ExecStartPre);
    }
  );
  transfer = mkBrowser "firefox" {
    enable = true;
    fileTransfer.enable = true;
  };
  transferContainer = transfer.virtualisation.quadlet.containers.firefox.containerConfig;
  invalidTransfer = mkBrowser "firefox" {
    enable = true;
    fileTransfer = {
      enable = true;
      hostPath = "relative";
      containerPath = "relative";
    };
  };
  scrape = lib.findFirst (
    s: s.job_name == "arr-exporter"
  ) null blizzard.config.sys.services.prometheus.extraScrapeConfigs;
  changedSonarr = configurations.sonarr-vm.extendModules {
    modules = [ { sys.services.arrExporter.sonarr.port = lib.mkForce 19707; } ];
  };
  changedHost = blizzard.extendModules {
    specialArgs.self.nixosConfigurations = configurations // {
      sonarr-vm = changedSonarr;
    };
  };
  changedScrape = lib.findFirst (
    s: s.job_name == "arr-exporter"
  ) null changedHost.config.sys.services.prometheus.extraScrapeConfigs;
in
assert lib.all (name: lib.assertMsg (arrContract name) "${name}: Arr family contract failed") names;
assert lib.all
  (name: lib.assertMsg (browserContract name) "${name}: browser family contract failed")
  [
    "brave"
    "firefox"
  ];
assert
  transferContainer.environments.PUID == "911" && transferContainer.environments.PGID == "1000";
assert transferContainer.environments.FILE_MANAGER_PATH == "/downloads";
assert
  transferContainer.volumes == [
    "/var/lib/firefox:/config"
    "/home/admin/Downloads:/downloads"
  ];
assert lib.elem "d /home/admin/Downloads 2770 1000 1000 -" transfer.systemd.tmpfiles.rules;
assert builtins.length (browserFailures "firefox" invalidTransfer) == 2;
assert map (s: s.labels.arr_service) scrape.static_configs == names;
assert (builtins.head changedScrape.static_configs).targets == [ "10.100.0.21:19707" ];
pkgs.runCommand "service-family-contracts"
  {
    nativeBuildInputs = [ pkgs.python3 ];
    fixtures = pkgs.writeText "browser-credential-fixtures.json" (builtins.toJSON credentials);
  }
  ''
    python ${./browser_credentials.py} "$fixtures"
    touch "$out"
  ''
