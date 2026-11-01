{
  pkgs,
  blizzard,
  crossSeedVm,
  qbittorrentVm,
}:
let
  inherit (pkgs) lib;
  # Exercise both phases explicitly so provisioning the live guest does not
  # invalidate the bootstrap contract.
  staged =
    (crossSeedVm.extendModules {
      modules = [
        { sys.services.cross-seed.enable = lib.mkForce false; }
      ];
    }).config;
  ready = crossSeedVm.extendModules {
    modules = [
      { sys.services.cross-seed.enable = lib.mkForce true; }
    ];
  };
  cfg = ready.config;
  qbittorrent = qbittorrentVm.config;
  service = cfg.systemd.services.cross-seed;
  settings = cfg.services.cross-seed.settings;
  missingSecret = ready.extendModules {
    modules = [
      { sys.secrets.crossSeedSettingsFile = lib.mkForce null; }
    ];
  };
  host = blizzard.extendModules {
    modules = [
      { sys.virtualisation.microvm.instances.cross-seed.enable = lib.mkForce true; }
    ];
  };
  instance = host.config.sys.virtualisation.microvm.instances.cross-seed;
  torrentDirectory =
    host.config.systemd.tmpfiles.settings."10-torrent-permissions"."/rpool/unenc/media/data/torrents".d;
  mediaShare = lib.findFirst (share: share.mountPoint == "/data") null cfg.microvm.shares;
in
# Bootstrap must not require a secret that cannot yet be encrypted for this guest.
assert !staged.services.cross-seed.enable;
assert !(staged.sops.secrets ? "cross-seed/settings");
assert !(staged.systemd.services ? cross-seed);
assert staged.users.users.cross-seed.isSystemUser;
assert lib.elem "users" staged.users.users.cross-seed.extraGroups;
assert lib.any (
  assertion: !assertion.assertion && lib.hasInfix "crossSeedSettingsFile" assertion.message
) missingSecret.config.assertions;

# The emitted configuration must recheck and stop candidates with missing bytes.
assert settings.action == "inject";
assert settings.matchMode == "flexible";
assert !settings.skipRecheck;
assert settings.autoResumeMaxDownload == 0;
assert !settings.ignoreNonRelevantFilesToResume;
assert settings.useClientTorrents && settings.torrentDir == null && settings.dataDirs == [ ];
assert settings.linkType == "hardlink" && settings.linkDirs == [ "/data/cross-seed" ];
assert settings.host == "127.0.0.1";
assert !(settings ? apiKey) && !(settings ? torznab) && !(settings ? torrentClients);
assert cfg.services.cross-seed.settingsFile == cfg.sops.secrets."cross-seed/settings".path;
assert cfg.sops.secrets."cross-seed/settings".owner == "root";
assert cfg.sops.secrets."cross-seed/settings".mode == "0400";
assert lib.elem "cross-seed.service" cfg.sops.secrets."cross-seed/settings".restartUnits;
assert lib.elem "sops-install-secrets.service" service.requires;
assert lib.elem "sops-install-secrets.service" service.after;

# Both applications see the same filesystem and can access group-writable links.
assert qbittorrent.systemd.services.qbittorrent.serviceConfig.Group == "users";
assert qbittorrent.users.users.qbittorrent.group == "qbittorrent";
assert lib.elem "qbittorrent"
  qbittorrent.systemd.services.qbittorrent.serviceConfig.SupplementaryGroups;
assert qbittorrent.systemd.services.qbittorrent.serviceConfig.UMask == "002";
assert torrentDirectory.mode == "2775";
assert torrentDirectory.user == "-";
assert torrentDirectory.group == "users";
assert mediaShare != null && mediaShare.source == "/rpool/unenc/media/data";
assert !mediaShare.readOnly;
assert lib.elem "users" service.serviceConfig.SupplementaryGroups;
assert service.serviceConfig.UMask == "0002";
assert lib.elem "/data/cross-seed" service.unitConfig.RequiresMountsFor;

# No publication or incoming API port; only the required outgoing service edges.
assert instance.enable && !instance.publication.enable && instance.portForward.ports == [ ];
assert
  builtins.attrNames instance.networkPolicy.allowedPeers == [
    "prowlarr"
    "qbittorrent"
  ];
assert lib.all (peer: peer.primaryService && peer.tcpPorts == [ ] && peer.udpPorts == [ ]) (
  builtins.attrValues instance.networkPolicy.allowedPeers
);
assert !(lib.elem cfg.sys.services.cross-seed.port cfg.networking.firewall.allowedTCPPorts);
assert cfg.systemd.network.networks."20-lan".networkConfig.Gateway == "10.100.0.1";
pkgs.runCommand "cross-seed-contract" { } "touch $out"
