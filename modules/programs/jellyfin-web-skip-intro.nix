{ lib, config, ... }:
let
  cfg = config.sys.programs.jellyfinWebSkipIntro;
in
{
  options.sys.programs.jellyfinWebSkipIntro.enable =
    lib.mkEnableOption "Inject Skip Intro button into Jellyfin Web";

  config = lib.mkMerge [
    {
      sys.programs.jellyfinWebSkipIntro.enable = lib.mkDefault (
        config.sys.services.jellyfin.enable or false
      );
    }

    (lib.mkIf cfg.enable {
      nixpkgs.overlays = [
        (_: prev: {
          jellyfin-web = prev.jellyfin-web.overrideAttrs (
            _: _: {
              installPhase = ''
                runHook preInstall

                # this is the important line
                sed -i "s#</head>#<script src=\"configurationpage?name=skip-intro-button.js\"></script></head>#" dist/index.html

                mkdir -p $out/share
                cp -a dist $out/share/jellyfin-web

                runHook postInstall
              '';
            }
          );
        })
      ];
    })
  ];
}
