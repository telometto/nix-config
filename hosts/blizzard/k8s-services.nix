{ VARS, ... }:
{
  # Kubernetes-deployed services that need Traefik routing
  # These services run in k3s and don't have dedicated NixOS modules yet

  services.traefik.dynamicConfigOptions.http = {
    routers = {
      overseerr = {
        rule = "Host(`requests.${VARS.domains.public}`)";
        service = "overseerr";
        entryPoints = [ "web" ];
        middlewares = [ "overseerr-headers" ];
      };

      firefox = {
        rule = "Host(`ff.${VARS.domains.public}`)";
        service = "firefox";
        entryPoints = [ "web" ];
        middlewares = [ "security-headers" ];
      };

      sabnzbd = {
        rule = "Host(`sab.${VARS.domains.public}`)";
        service = "sabnzbd";
        entryPoints = [ "web" ];
        middlewares = [ "security-headers" ];
      };

      bazarr = {
        rule = "Host(`subs.${VARS.domains.public}`)";
        service = "bazarr";
        entryPoints = [ "web" ];
        middlewares = [ "security-headers" ];
      };

      lingarr = {
        rule = "Host(`lingarr.${VARS.domains.public}`)";
        service = "lingarr";
        entryPoints = [ "web" ];
        middlewares = [ "security-headers" ];
      };

      prowlarr = {
        rule = "Host(`indexer.${VARS.domains.public}`)";
        service = "prowlarr";
        entryPoints = [ "web" ];
        middlewares = [ "security-headers" ];
      };

      radarr = {
        rule = "Host(`movies.${VARS.domains.public}`)";
        service = "radarr";
        entryPoints = [ "web" ];
        middlewares = [ "security-headers" ];
      };

      readarr = {
        rule = "Host(`books.${VARS.domains.public}`)";
        service = "readarr";
        entryPoints = [ "web" ];
        middlewares = [ "security-headers" ];
      };

      sonarr = {
        rule = "Host(`series.${VARS.domains.public}`)";
        service = "sonarr";
        entryPoints = [ "web" ];
        middlewares = [ "security-headers" ];
      };

      searx = {
        rule = "Host(`search.${VARS.domains.public}`)";
        service = "searx";
        entryPoints = [ "web" ];
        middlewares = [
          "security-headers"
          "crowdsec"
        ];
      };

      adguard = {
        rule = "Host(`adguard.${VARS.domains.public}`)";
        service = "adguard";
        entryPoints = [ "web" ];
        middlewares = [
          "security-headers"
          "crowdsec"
        ];
      };

      actual = {
        rule = "Host(`actual.${VARS.domains.public}`)";
        service = "actual";
        entryPoints = [ "web" ];
        middlewares = [
          "security-headers"
          "crowdsec"
        ];
      };
    };

    services = {
      overseerr.loadBalancer.servers = [ { url = "http://localhost:10001"; } ];
      prowlarr.loadBalancer.servers = [ { url = "http://localhost:10010"; } ];
      sonarr.loadBalancer.servers = [ { url = "http://localhost:10020"; } ];
      radarr.loadBalancer.servers = [ { url = "http://localhost:10021"; } ];
      readarr.loadBalancer.servers = [ { url = "http://localhost:10022"; } ];
      bazarr.loadBalancer.servers = [ { url = "http://localhost:10030"; } ];
      lingarr.loadBalancer.servers = [ { url = "http://localhost:10031"; } ];
      sabnzbd.loadBalancer.servers = [ { url = "http://localhost:10050"; } ];
      firefox.loadBalancer.servers = [ { url = "http://localhost:10060"; } ];
      searx.loadBalancer.servers = [ { url = "http://10.100.0.12:11002"; } ];
      adguard.loadBalancer.servers = [ { url = "http://10.100.0.10:11016"; } ];
      actual.loadBalancer.servers = [ { url = "http://10.100.0.11:11005"; } ];
    };
  };
}
