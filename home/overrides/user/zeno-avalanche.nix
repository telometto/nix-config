# User-specific configuration for zeno on avalanche host
# This file is automatically imported only for zeno on avalanche
{ pkgs, ... }:
{
  imports = [ ./zeno-desktop-ssh.nix ];

  home.packages = [
    #pkgs.tuxguitar # Guitar tablature editor and player
    pkgs.pgadmin4-desktopmode # PostgreSQL administration tool
    pkgs.vorta # Borg backup GUI
    # pkgs.logseq # issues with electron version
    pkgs.rendercv
    pkgs.claude-code
    pkgs.signal-desktop
    pkgs.uv
    # pkgs.rustdesk-flutter
    # (pkgs.jellyfin-media-player.override {
    #   qtwebengine = pkgs.kdePackages.qtwebengine; # overridden due to CVEs
    # }) # disabled due to version mismatch; kept as reference
  ];

  hm = {
    langs = "nb_NO.UTF-8";

    programs = {
      development = {
        extraPackages = [
          pkgs.vscode
          pkgs.jetbrains.idea-oss
        ];

        git.lfs = true;
      };
    };
  };
}
