{ lib, config, ... }:
let
  cfg = config.telometto.programs.jellyfinWebSkipIntro;
in
{
  options.telometto.programs.jellyfinWebSkipIntro.enable =
    lib.mkEnableOption "Inject Skip Intro button into Jellyfin Web";

  config = lib.mkMerge [
    # Follow Jellyfin service by default
    {
      telometto.programs.jellyfinWebSkipIntro.enable = lib.mkDefault (
        config.telometto.services.jellyfin.enable or false
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
