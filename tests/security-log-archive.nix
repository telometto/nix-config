{ pkgs }:
let
  specs = import ../lib/security-log-archive-alerts.nix;
  rules = pkgs.writeText "security-log-archive-alerts.json" (
    builtins.toJSON {
      groups = [
        {
          name = "security-log-archive";
          rules = map (s: {
            alert = s.uid;
            inherit (s) expr;
            for = s.hold;
            labels.severity = s.severity;
          }) specs;
        }
      ];
    }
  );
  cases = pkgs.writeText "security-log-archive-alert-tests.json" (
    builtins.toJSON {
      rule_files = [ rules ];
      evaluation_interval = "1m";
      tests = [
        {
          interval = "1m";
          input_series = [
            {
              series = "security_log_archive_buffer_bytes";
              values = "0+0x15";
            }
            {
              series = "security_log_archive_buffer_limit_bytes";
              values = "100+0x15";
            }
            {
              series = "security_log_archive_paused";
              values = "0+0x15";
            }
            {
              series = "security_log_archive_loss_timestamp_seconds";
              values = "0+0x15";
            }
          ];
          promql_expr_test = [
            {
              inherit ((builtins.elemAt specs 2)) expr;
              eval_time = "15m";
              exp_samples = [ ];
            }
            {
              inherit ((builtins.elemAt specs 3)) expr;
              eval_time = "15m";
              exp_samples = [ ];
            }
            {
              inherit ((builtins.elemAt specs 4)) expr;
              eval_time = "15m";
              exp_samples = [ ];
            }
          ];
        }
        {
          interval = "1m";
          input_series = [
            {
              series = "security_log_archive_buffer_bytes";
              values = "95+0x15";
            }
            {
              series = "security_log_archive_buffer_limit_bytes";
              values = "100+0x15";
            }
            {
              series = "security_log_archive_paused";
              values = "1+0x15";
            }
            {
              series = "security_log_archive_loss_timestamp_seconds";
              values = "600+0x15";
            }
          ];
          promql_expr_test = [
            {
              inherit ((builtins.elemAt specs 2)) expr;
              eval_time = "15m";
              exp_samples = [
                {
                  labels = "{}";
                  value = 0.95;
                }
              ];
            }
            {
              inherit ((builtins.elemAt specs 4)) expr;
              eval_time = "15m";
              exp_samples = [
                {
                  labels = "{}";
                  value = 300;
                }
              ];
            }
          ];
          alert_rule_test = [
            {
              eval_time = "15m";
              alertname = "security-archive-paused";
              exp_alerts = [ { exp_labels.severity = "critical"; } ];
            }
          ];
        }
        {
          interval = "1m";
          input_series = [
            {
              series = "security_log_archive_paused";
              values = "1+0x5 0+0x15";
            }
            {
              series = "security_log_archive_buffer_bytes";
              values = "95+0x5 0+0x15";
            }
            {
              series = "security_log_archive_buffer_limit_bytes";
              values = "100+0x21";
            }
          ];
          alert_rule_test = [
            {
              eval_time = "15m";
              alertname = "security-archive-paused";
              exp_alerts = [ ];
            }
          ];
        }
      ];
    }
  );
in
pkgs.runCommand "security-log-archive-tests"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.restic
      pkgs.rclone
      pkgs.prometheus.cli
    ];
  }
  ''
    mkdir -p source/packages/security-log-archive source/tests
    cp ${../packages/security-log-archive/archive.py} source/packages/security-log-archive/archive.py
    cp ${../packages/security-log-archive/model.py} source/packages/security-log-archive/model.py
    cp ${./security_log_archive_test.py} source/tests/security_log_archive_test.py
    cp ${./security_log_archive_integration.py} source/tests/security_log_archive_integration.py
    python source/tests/security_log_archive_test.py
    python source/tests/security_log_archive_integration.py
    promtool check rules ${rules}
    promtool test rules ${cases}
    touch $out
  ''
