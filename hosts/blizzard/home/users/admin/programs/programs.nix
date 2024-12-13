{ config, lib, pkgs, VARS, ... }:

{
  programs = {
    keychain = {
      keys = [
        "borg-blizzard"
        "sops-hm-blizzard"
        "zeno-blizzard"
      ];
    };
  };
}
