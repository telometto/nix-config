{
  kaizer,
  pkgs,
  snowfall,
  VARS,
}:
let
  inherit (pkgs) lib;
  snowfallConfig = snowfall.config;
  kaizerConfig = kaizer.config;
  zenoUsername = VARS.users.zeno.user;
  lukeUsername = VARS.users.luke.user;
  zenoHome = snowfallConfig.home-manager.users.${zenoUsername};
  kaizerHome = kaizerConfig.home-manager.users.${lukeUsername};
  disabledGitea = snowfall.extendModules {
    modules = [
      {
        home-manager.users.${zenoUsername}.hm.programs.gitea.enable = lib.mkForce false;
      }
    ];
  };
  sopsDisabled = snowfall.extendModules {
    modules = [
      {
        home-manager.users.${zenoUsername}.hm.security.sops.enable = lib.mkForce false;
      }
    ];
  };
  disabledGiteaHome = disabledGitea.config.home-manager.users.${zenoUsername};
  sopsDisabledHome = sopsDisabled.config.home-manager.users.${zenoUsername};
  giteaUrl = "https://git.${VARS.domains.public}";
  giteaTemplate = zenoHome.sops.templates."gitea-git-http";
  giteaInclude = lib.findFirst (
    include: include.path == giteaTemplate.path
  ) null zenoHome.programs.git.includes;
  giteaHelper = zenoHome.programs.git.settings.credential.${giteaUrl}.helper;
  sopsTarget =
    if zenoHome.sops.gnupg.home != null then "graphical-session-pre.target" else "default.target";
  hasFailedAssertion =
    message: cfg:
    lib.any (assertion: !assertion.assertion && assertion.message == message) (cfg.assertions or [ ]);
in
assert snowfallConfig.users.users.${zenoUsername}.uid == 1000;
assert kaizerConfig.users.users.${lukeUsername}.uid == null;
assert zenoHome.sops.defaultSymlinkPath == "%r/secrets";
assert zenoHome.sops.defaultSecretsMountPoint == "%r/secrets.d";
assert zenoHome.hm.programs.gitea.enable;
assert builtins.hasAttr "gitea/cf_access_id" zenoHome.sops.secrets;
assert builtins.hasAttr "gitea/cf_access_secret" zenoHome.sops.secrets;
assert zenoHome.sops.secrets."gitea/cf_access_id".mode == "0400";
assert zenoHome.sops.secrets."gitea/cf_access_secret".mode == "0400";
assert
  giteaTemplate.path
  == "${zenoHome.xdg.configHome}/sops-nix/secrets/rendered/gitea-git-http";
assert giteaTemplate.mode == "0400";
assert lib.hasInfix "[http \"${giteaUrl}/\"]" giteaTemplate.content;
assert lib.hasInfix "<SOPS:" giteaTemplate.content;
assert lib.hasInfix "CF-Access-Client-Id:" giteaTemplate.content;
assert lib.hasInfix "CF-Access-Client-Secret:" giteaTemplate.content;
assert giteaHelper == [ "" "libsecret" ];
assert giteaInclude != null;
assert lib.elem sopsTarget zenoHome.systemd.user.services.sops-nix.Unit.Before;
assert lib.elem sopsTarget zenoHome.systemd.user.services.sops-nix.Install.WantedBy;
assert !(builtins.hasAttr "gitea/cf_access_id" disabledGiteaHome.sops.secrets);
assert !(builtins.hasAttr "gitea-git-http" disabledGiteaHome.sops.templates);
assert !(builtins.hasAttr giteaUrl (disabledGiteaHome.programs.git.settings.credential or { }));
assert !(kaizerHome.hm.programs.gitea.enable or false);
assert !(builtins.hasAttr giteaUrl (kaizerHome.programs.git.settings.credential or { }));
assert !(builtins.hasAttr "gitea/cf_access_id" sopsDisabledHome.sops.secrets);
assert !(builtins.hasAttr "gitea-git-http" sopsDisabledHome.sops.templates);
assert !(builtins.hasAttr giteaUrl (sopsDisabledHome.programs.git.settings.credential or { }));
assert hasFailedAssertion
  "hm.programs.gitea requires hm.security.sops.enable = true."
  sopsDisabledHome;
pkgs.runCommand "user-account-tests" { } ''
  touch "$out"
''
