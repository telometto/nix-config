{ config, pkgs, lib, ... }:
{
  # Upstream module sets `path = lib.mkForce []`, but journalctl acquisition needs systemd in PATH
  systemd.services.crowdsec.path = lib.mkForce [ pkgs.systemd ];

  services.crowdsec = {
    enable = true;

    settings = {
      lapi.credentialsFile = "/var/lib/crowdsec/state/local_api_credentials.yaml";
      capi.credentialsFile = "/var/lib/crowdsec/state/online_api_credentials.yaml";

      console = {
        tokenFile = config.sys.secrets.crowdsecConsoleTokenFile;

        configuration = {
          share_manual_decisions = true;
          share_custom = true;
          share_tainted = true;
          share_context = true;
          console_management = true;
        };
      };

      general.api.server = {
        enable = true;
        listen_uri = "127.0.0.1:8085";
      };
    };

    hub = {
      collections = [
        "crowdsecurity/linux"
        "crowdsecurity/traefik"
        "crowdsecurity/http-cve"
        "crowdsecurity/whitelist-good-actors"
      ];

      scenarios = [
        "crowdsecurity/ssh-bf"
        "crowdsecurity/ssh-slow-bf"
        "crowdsecurity/http-crawl-non_statics"
        "crowdsecurity/http-probing"
        "crowdsecurity/http-sensitive-files"
        "crowdsecurity/http-bad-user-agent"
      ];

      postOverflows = [
        "crowdsecurity/auditd-nix-wrappers-whitelist-process"
        "crowdsecurity/cdn-whitelist"
      ];
    };

    localConfig = {
      acquisitions = [
        {
          source = "journalctl";
          journalctl_filter = [
            "_SYSTEMD_UNIT=traefik.service"
          ];

          labels = {
            type = "traefik";
            service = "traefik";
            environment = "production";
          };
        }
      ];

      contexts = [
        {
          context = {
            target_host = [ "evt.Meta.http_host" ];
            target_uri = [ "evt.Meta.http_path" ];
            http_method = [ "evt.Meta.http_verb" ];
            http_status = [ "evt.Meta.http_status" ];
            user_agent = [ "evt.Meta.http_user_agent" ];
          };
        }
      ];

      profiles = [
        {
          name = "default_ip_remediation";
          filters = [ "Alert.Remediation == true && Alert.GetScope() == 'Ip'" ];

          decisions = [
            {
              type = "ban";
              duration = "4h";
            }
          ];
          on_success = "break";
        }
      ];
    };
  };
}
