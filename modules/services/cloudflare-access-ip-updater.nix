{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.telometto.services.cloudflareAccessIpUpdater;

  # Determine API endpoint based on whether appId is provided
  # Reusable policy: /accounts/{account_id}/access/policies/{policy_id}
  # App-specific:    /accounts/{account_id}/access/apps/{app_id}/policies/{policy_id}
  apiEndpoint =
    if cfg.appId == null then
      "https://api.cloudflare.com/client/v4/accounts/\$ACCOUNT_ID/access/policies/\$POLICY_ID"
    else
      "https://api.cloudflare.com/client/v4/accounts/\$ACCOUNT_ID/access/apps/\$APP_ID/policies/\$POLICY_ID";

  # Script to update Cloudflare Access policy with current IP
  updateScript = pkgs.writeShellScript "cloudflare-access-ip-updater" ''
    set -euo pipefail

    # Configuration
    ACCOUNT_ID="${cfg.accountId}"
    ${lib.optionalString (cfg.appId != null) ''APP_ID="${cfg.appId}"''}
    POLICY_ID="${cfg.policyId}"
    API_TOKEN_FILE="${cfg.apiTokenFile}"
    STATE_FILE="/var/lib/cloudflare-access-ip-updater/last-ip"
    API_ENDPOINT="${apiEndpoint}"

    # Read API token
    if [[ ! -f "$API_TOKEN_FILE" ]]; then
      echo "Error: API token file not found: $API_TOKEN_FILE"
      exit 1
    fi
    API_TOKEN=$(${pkgs.coreutils}/bin/cat "$API_TOKEN_FILE" | ${pkgs.coreutils}/bin/tr -d '[:space:]')

    # Get current public IP
    CURRENT_IP=$(${pkgs.curl}/bin/curl -sf ${lib.escapeShellArg cfg.ipService} | ${pkgs.coreutils}/bin/tr -d '[:space:]')
    if [[ -z "$CURRENT_IP" ]]; then
      echo "Error: Failed to get current IP"
      exit 1
    fi
    echo "Current IP: $CURRENT_IP"

    # Check if IP has changed
    if [[ -f "$STATE_FILE" ]]; then
      LAST_IP=$(${pkgs.coreutils}/bin/cat "$STATE_FILE")
      if [[ "$CURRENT_IP" == "$LAST_IP" ]]; then
        echo "IP unchanged ($CURRENT_IP), skipping update"
        exit 0
      fi
      echo "IP changed from $LAST_IP to $CURRENT_IP"
    fi

    # Fetch current policy to preserve other settings
    echo "Fetching current policy from: $API_ENDPOINT"
    POLICY_RESPONSE=$(${pkgs.curl}/bin/curl -sf \
      -H "Authorization: Bearer $API_TOKEN" \
      -H "Content-Type: application/json" \
      "$API_ENDPOINT")

    if [[ -z "$POLICY_RESPONSE" ]]; then
      echo "Error: Failed to fetch policy"
      exit 1
    fi

    # Extract policy details using jq
    POLICY_NAME=$(echo "$POLICY_RESPONSE" | ${pkgs.jq}/bin/jq -r '.result.name')
    POLICY_DECISION=$(echo "$POLICY_RESPONSE" | ${pkgs.jq}/bin/jq -r '.result.decision')
    POLICY_PRECEDENCE=$(echo "$POLICY_RESPONSE" | ${pkgs.jq}/bin/jq -r '.result.precedence')

    echo "Policy: $POLICY_NAME (decision: $POLICY_DECISION, precedence: $POLICY_PRECEDENCE)"

    # Build the updated policy JSON
    # This creates a policy with the IP rule for bypass
    UPDATE_PAYLOAD=$(${pkgs.jq}/bin/jq -n \
      --arg name "$POLICY_NAME" \
      --arg decision "$POLICY_DECISION" \
      --argjson precedence "$POLICY_PRECEDENCE" \
      --arg ip "$CURRENT_IP/32" \
      '{
        name: $name,
        decision: $decision,
        precedence: $precedence,
        include: [
          { ip: { ip: $ip } }
        ],
        exclude: [],
        require: []
      }')

    echo "Updating policy with new IP..."
    UPDATE_RESPONSE=$(${pkgs.curl}/bin/curl -sf \
      -X PUT \
      -H "Authorization: Bearer $API_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$UPDATE_PAYLOAD" \
      "$API_ENDPOINT")

    # Check if update was successful
    SUCCESS=$(echo "$UPDATE_RESPONSE" | ${pkgs.jq}/bin/jq -r '.success')
    if [[ "$SUCCESS" != "true" ]]; then
      echo "Error: Failed to update policy"
      echo "$UPDATE_RESPONSE" | ${pkgs.jq}/bin/jq '.errors'
      exit 1
    fi

    # Save current IP to state file
    ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$STATE_FILE")"
    echo "$CURRENT_IP" > "$STATE_FILE"

    echo "Successfully updated Cloudflare Access policy with IP: $CURRENT_IP"
  '';
in
{
  options.telometto.services.cloudflareAccessIpUpdater = {
    enable = lib.mkEnableOption "Cloudflare Access IP Updater";

    accountId = lib.mkOption {
      type = lib.types.str;
      description = "Cloudflare Account ID";
      example = "abcdef1234567890abcdef1234567890";
    };

    appId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Cloudflare Access Application ID.
        Only required for app-specific policies.
        Leave null for reusable policies (recommended).
      '';
      example = "12345678-1234-1234-1234-123456789012";
    };

    policyId = lib.mkOption {
      type = lib.types.str;
      description = "Cloudflare Access Policy ID to update with dynamic IP";
      example = "87654321-4321-4321-4321-210987654321";
    };

    apiTokenFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to file containing Cloudflare API token.
        Token needs "Zero Trust: Edit" permission.
        Use sops.secrets.*.path for secure storage.
      '';
      example = "/run/secrets/cloudflare-access-api-token";
    };

    ipService = lib.mkOption {
      type = lib.types.str;
      default = "https://ifconfig.me/ip";
      description = "URL to fetch current public IP address";
      example = "https://api.ipify.org";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "5min";
      description = "How often to check for IP changes (systemd time format)";
      example = "15min";
    };

    onCalendar = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Calendar expression for when to run (alternative to interval).
        If set, this takes precedence over interval.
      '';
      example = "*:0/10"; # Every 10 minutes
    };

    persistent = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run immediately if a scheduled run was missed";
    };
  };

  config = lib.mkIf cfg.enable {
    # Create state directory
    systemd = {
      tmpfiles.rules = [
        "d /var/lib/cloudflare-access-ip-updater 0750 root root -"
      ];

      # Main service
      services.cloudflare-access-ip-updater = {
        description = "Update Cloudflare Access policy with current public IP";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];

        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${updateScript}";
          # Security hardening
          DynamicUser = false;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ReadWritePaths = [ "/var/lib/cloudflare-access-ip-updater" ];
          NoNewPrivileges = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          RestrictSUIDSGID = true;
          # Network access required
          PrivateNetwork = false;
        };
      };

      # Timer to run periodically
      timers.cloudflare-access-ip-updater = {
        description = "Timer for Cloudflare Access IP Updater";
        wantedBy = [ "timers.target" ];

        timerConfig = {
          Unit = "cloudflare-access-ip-updater.service";
          Persistent = cfg.persistent;
        }
        // (
          if cfg.onCalendar != null then
            { OnCalendar = cfg.onCalendar; }
          else
            {
              OnUnitActiveSec = cfg.interval;
              OnBootSec = "1min";
            }
        );
      };
    };
  };
}
