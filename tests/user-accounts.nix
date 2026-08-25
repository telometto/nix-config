{
  kaizer,
  pkgs,
  snowfall,
  VARS,
}:
let
  snowfallConfig = snowfall.config;
  kaizerConfig = kaizer.config;
  zenoUsername = VARS.users.zeno.user;
  lukeUsername = VARS.users.luke.user;
  zenoHome = snowfallConfig.home-manager.users.${zenoUsername};
in
assert snowfallConfig.users.users.${zenoUsername}.uid == 1000;
assert kaizerConfig.users.users.${lukeUsername}.uid == null;
assert zenoHome.sops.defaultSymlinkPath == "%r/secrets";
assert zenoHome.sops.defaultSecretsMountPoint == "%r/secrets.d";
pkgs.runCommand "user-account-tests" { } ''
  touch "$out"
''
