{
  lib,
  config,
  ...
}:
let
  cfg = config.sys.services.grafana.pushover;
in
{
  options.sys.services.grafana.pushover = {
    enable = lib.mkEnableOption "Pushover notifications for Grafana";

    apiTokenFile = lib.mkOption {
      type = lib.types.str;
      description = ''
        Path to file containing the Pushover API token/application key.
        This should be a SOPS secret or secure file.
      '';
      example = "/run/secrets/pushover-api-token";
    };

    userKeyFile = lib.mkOption {
      type = lib.types.str;
      description = ''
        Path to file containing the Pushover user key.
        This should be a SOPS secret or secure file.
      '';
      example = "/run/secrets/pushover-user-key";
    };

    contactPoints = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Name of the contact point";
              example = "pushover-home";
            };

            priority = lib.mkOption {
              type = lib.types.enum [
                -2
                -1
                0
                1
                2
              ];
              default = 0;
              description = ''
                Pushover priority level:
                -2: Lowest priority (no notification)
                -1: Low priority (no sound/vibration)
                0: Normal priority (default)
                1: High priority (bypass quiet hours)
                2: Emergency (requires acknowledgement)
              '';
            };

            sound = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                Pushover notification sound name.
                See https://pushover.net/api#sounds for available sounds.
                Common options: pushover, bike, bugle, cashregister, classical, cosmic, 
                falling, gamelan, incoming, intermission, magic, mechanical, pianobar, 
                siren, spacealarm, tugboat, alien, climb, persistent, echo, updown, 
                vibrate, none
              '';
              example = "siren";
            };

            device = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Specific device name to send notification to (optional)";
              example = "iphone";
            };

            retry = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = null;
              description = ''
                How often (in seconds) the Pushover servers will retry the notification 
                to the user. Required for priority 2 (emergency) alerts. Minimum 30 seconds.
              '';
              example = 60;
            };

            expire = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = null;
              description = ''
                How many seconds notification will continue to be retried 
                (every retry seconds). Required for priority 2 (emergency) alerts. Maximum 10800.
              '';
              example = 3600;
            };

            disableResolveMessage = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Disable sending resolved notifications";
            };
          };
        }
      );
      default = [ ];
      description = "List of Pushover contact points to create";
      example = lib.literalExpression ''
        [
          {
            name = "pushover-normal";
            priority = 0;
            sound = "pushover";
          }
          {
            name = "pushover-critical";
            priority = 1;
            sound = "siren";
          }
        ]
      '';
    };

    messageTemplates = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Enable custom message templates as described in the blog post.
          Creates templates for well-formatted notifications with alert details,
          panel/dashboard links, and emoji indicators for firing/resolved states.
        '';
      };
    };
  };

  config = lib.mkIf (cfg.enable && config.sys.services.grafana.enable) {
    assertions = [
      {
        assertion = cfg.contactPoints != [ ];
        message = "At least one Pushover contact point must be defined when grafana.pushover is enabled";
      }
      {
        assertion = lib.all (
          cp:
          (cp.priority == 2) -> (cp.retry != null && cp.expire != null)
        ) cfg.contactPoints;
        message = "Pushover contact points with priority 2 (emergency) must have retry and expire set";
      }
    ];

    services.grafana.provision.alerting = {
      contactPoints.settings = {
        apiVersion = 1;
        contactPoints = map (cp: {
          orgId = 1;
          name = cp.name;
          receivers = [
            {
              uid = lib.strings.sanitizeDerivationName cp.name;
              type = "pushover";
              settings = {
                apiToken = "$__file{${cfg.apiTokenFile}}";
                userKey = "$__file{${cfg.userKeyFile}}";
                priority = toString cp.priority;
                okpriority = toString cp.priority;
                sound = lib.mkIf (cp.sound != null) cp.sound;
                oksound = lib.mkIf (cp.sound != null) cp.sound;
                device = lib.mkIf (cp.device != null) cp.device;
                retry = lib.mkIf (cp.retry != null) (toString cp.retry);
                expire = lib.mkIf (cp.expire != null) (toString cp.expire);
              };
              disableResolveMessage = cp.disableResolveMessage;
            }
          ];
        }) cfg.contactPoints;
      };

      templates.settings = lib.mkIf cfg.messageTemplates.enable {
        apiVersion = 1;
        templates = [
          {
            orgId = 1;
            name = "pushover-templates";
            template = ''
              {{ define "myalert" }}
              {{- range .Annotations.SortedPairs }}
              {{ .Value }}
              {{- end }}

              {{- if gt (len .PanelURL) 0 }}
              Panel: {{ .PanelURL }}
              {{- end }}

              {{- if gt (len .DashboardURL) 0 }}
              Dashboard: {{ .DashboardURL }}
              {{- end }}

              {{- range .Labels.SortedPairs }}
              {{ .Name }}: {{ .Value }}
              {{- end }}

              {{- if gt (len .SilenceURL) 0 }}
              Silence: {{ .SilenceURL }}
              {{- end }}
              {{ end }}

              {{ define "mymessage" }}
              {{- if gt (len .Alerts.Firing) 0 }}
              ⚠️ FIRING
              {{- range .Alerts.Firing }}
              {{ template "myalert" . }}
              {{- end }}
              {{- end }}

              {{- if gt (len .Alerts.Resolved) 0 }}
              ❇️ RESOLVED
              {{- range .Alerts.Resolved }}
              {{ template "myalert" . }}
              {{- end }}
              {{- end }}
              {{ end }}

              {{ define "title" }}
              [{{ .Status | toUpper }}: {{ if eq .Status "firing" }}{{ .Alerts.Firing | len }}{{ else if eq .Status "resolved" }}{{ .Alerts.Resolved | len }}{{ end }}] {{ .CommonLabels.severity | toUpper }} {{ .CommonLabels.alertname }}
              {{- end }}
            '';
          }
        ];
      };
    };

    services.grafana.settings = lib.mkIf cfg.messageTemplates.enable {
      alerting = {
        # Use the custom templates for all notifications
        templates = {
          message = "{{ template \"mymessage\" . }}";
          title = "{{ template \"title\" . }}";
        };
      };
    };
  };
}
