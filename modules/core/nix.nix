{ lib, config, ... }:
{
  nix = {
    settings = {
      trusted-users = [
        "root"
        "@wheel"
      ];

      experimental-features = [
        "nix-command"
        "flakes"
      ];

      auto-optimise-store = lib.mkDefault true;
      download-buffer-size = lib.mkDefault 536870912;
    };

    gc = {
      automatic = lib.mkDefault true;
      dates = lib.mkDefault "weekly";
      options = lib.mkDefault "--delete-older-than 7d";
    };

    optimise = {
      automatic = lib.mkDefault true;
      dates = lib.mkDefault [ "02:00" ];
    };

    extraOptions = lib.mkDefault "!include ${config.sops.templates."access-tokens".path}";
  };
}
