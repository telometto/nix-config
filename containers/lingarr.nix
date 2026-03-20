# Lingarr stack: automated subtitle translation with LibreTranslate + Ollama
{ lib, config, ... }:
let
  stackCfg = config.sys.virtualisation.podman.stacks.lingarr;
in
{
  options.sys.virtualisation.podman.stacks.lingarr = {
    mediaDir = lib.mkOption {
      type = lib.types.str;
      default = "/rpool/unenc/media/data/media";
      description = "Base path for media directories (movies/, tv/).";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/rpool/unenc/apps/docker";
      description = "Base path for persistent application data.";
    };
  };

  config.sys.virtualisation.podman.stacks.lingarr = {
    containers = {
      lingarr = {
        image = "lingarr/lingarr:latest";
        ports = [ "11025:9876" ];
        environment = {
          ASPNETCORE_URLS = "http://+:9876";
          MAX_CONCURRENT_JOBS = "1";
          DB_HANGFIRE_SQLITE_PATH = "/app/config/Hangfire.db";
        };
        volumes = [
          "${stackCfg.mediaDir}/movies:/data/media/movies"
          "${stackCfg.mediaDir}/tv:/data/media/tv"
          "${stackCfg.dataDir}/lingarr:/app/config"
        ];
        dependsOn = [
          "libretranslate"
          "ollama"
        ];
        extraOptions = [ "--security-opt=apparmor:unconfined" ];
      };

      libretranslate = {
        image = "libretranslate/libretranslate:latest";
        ports = [ "11026:5000" ];
        environment = {
          LT_LOAD_ONLY = "en,it,nb";
        };
        volumes = [
          "${stackCfg.dataDir}/libretranslate:/home/libretranslate/.local/share/argos-translate"
        ];
        extraOptions = [ "--security-opt=apparmor:unconfined" ];
      };

      ollama = {
        image = "ollama/ollama:latest";
        ports = [ "11434:11434" ];
        volumes = [
          "${stackCfg.dataDir}/ollama:/root/.ollama"
        ];
        extraOptions = [ "--security-opt=apparmor:unconfined" ];
      };
    };
  };
}
