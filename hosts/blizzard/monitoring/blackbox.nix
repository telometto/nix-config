{ VARS, ... }:
let
  matrixBaseUrl = "https://matrix.${VARS.domains.public}";
in
{
  sys.services.blackbox = {
    enable = true;

    # These targets deliberately use public URLs. They exercise DNS,
    # Cloudflare Tunnel, Traefik/CrowdSec, Nginx, and the Matrix services.
    targets = [
      {
        service = "matrix";
        name = "client-api";
        url = "${matrixBaseUrl}/_matrix/client/versions";
        requiredJsonFields = [ "versions" ];
      }
      {
        service = "matrix";
        name = "oidc-discovery";
        url = "${matrixBaseUrl}/.well-known/openid-configuration";
        expectedJsonFields.issuer = "${matrixBaseUrl}/";
      }
      {
        service = "matrix";
        name = "federation-discovery";
        url = "https://${VARS.domains.public}/.well-known/matrix/server";
        expectedJsonFields."m.server" = "matrix.${VARS.domains.public}:443";
      }
      {
        service = "matrix";
        name = "federation-endpoint";
        url = "${matrixBaseUrl}/_matrix/federation/v1/version";
        requiredJsonFields = [ "server" ];
      }
    ];
  };
}
