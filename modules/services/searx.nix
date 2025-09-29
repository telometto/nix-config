{ lib, config, ... }:
let cfg = config.telometto.services.searx or { };
in {
  options.telometto.services.searx = {
    enable = lib.mkEnableOption "Searx Meta Search";
    port = lib.mkOption {
      type = lib.types.port;
      default = 7777;
    };
    bind = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
    };
    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Owner/extension point merged into services.searx.settings.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.searx = {
      enable = true;
      redisCreateLocally = true;
      settings = lib.mkMerge [
        {
          server = {
            # Use centralized secrets bridge; avoids direct SOPS references here
            secret_key = config.telometto.secrets.searxSecretKeyFile;
            inherit (cfg) port;
            bind_address = cfg.bind;
          };
          search.formats = [ "html" "json" "rss" ];
        }
        cfg.settings
      ];
    };
  };
}
