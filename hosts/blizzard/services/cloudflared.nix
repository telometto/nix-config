{ config, VARS, ... }:
{
  sys.services.cloudflared = {
    enable = true;

    tunnelId = "ce54cb73-83b2-4628-8246-26955d280641";
    credentialsFile = config.sys.secrets.cloudflaredCredentialsFile;

    ingress = {
      "metrics.${VARS.domains.public}" = "http://localhost:80";

      "requests.${VARS.domains.public}" = "http://localhost:80";

      "ombi.${VARS.domains.public}" = "http://localhost:80";
      "tautulli.${VARS.domains.public}" = "http://localhost:80";
      "git.${VARS.domains.public}" = "http://localhost:80";

      "ff.${VARS.domains.public}" = "http://localhost:80";
      "sab.${VARS.domains.public}" = "http://localhost:80";

      "subs.${VARS.domains.public}" = "http://localhost:80";
      "lingarr.${VARS.domains.public}" = "http://localhost:80";
      "indexer.${VARS.domains.public}" = "http://localhost:80";
      "movies.${VARS.domains.public}" = "http://localhost:80";
      "books.${VARS.domains.public}" = "http://localhost:80";
      "series.${VARS.domains.public}" = "http://localhost:80";

      "ssh-git.${VARS.domains.public}" = "ssh://10.100.0.16:2222";
    };
  };
}
