[
  {
    uid = "security-archive-collector";
    title = "Security archive collection is unavailable";
    severity = "critical";
    hold = "2m";
    expr = "absent(security_log_archive_collector_timestamp_seconds) or time() - security_log_archive_collector_timestamp_seconds > 90";
    description = "Inspect the collector and the spool. Do not delete pending segments or reset its journal cursor.";
  }
  {
    uid = "security-archive-delivery";
    title = "Security archive delivery exceeds five minutes";
    severity = "warning";
    hold = "2m";
    expr = "time() - security_log_archive_uploaded_watermark_seconds > 300 or security_log_archive_oldest_pending_age_seconds > 300";
    description = "Inspect upload failures, rsync.net connectivity and pending age. A fresh upload does not imply that older backlog has cleared.";
  }
  {
    uid = "security-archive-capacity";
    title = "Security archive buffer exceeds 80 percent";
    severity = "warning";
    hold = "5m";
    expr = "security_log_archive_buffer_bytes / security_log_archive_buffer_limit_bytes > 0.8";
    description = "Restore delivery before the archive pauses. Retain all unacknowledged records.";
  }
  {
    uid = "security-archive-paused";
    title = "Security archive collection is paused or near capacity";
    severity = "critical";
    hold = "0s";
    expr = "security_log_archive_paused > 0 or security_log_archive_buffer_bytes / security_log_archive_buffer_limit_bytes > 0.9";
    description = "Collection preserves unsent evidence at its buffer or filesystem limit. Restore delivery and inspect available journal history before resuming.";
  }
  {
    uid = "security-archive-loss";
    title = "Security archive detected an evidence gap or upstream loss";
    severity = "critical";
    hold = "0s";
    expr = "time() - security_log_archive_loss_timestamp_seconds < 600";
    description = "Record the affected interval and inspect gap records or CrowdSec loss reports. An uploader cannot recover records lost before journaling.";
  }
  {
    uid = "security-archive-schema";
    title = "Security archive encountered unsupported records";
    severity = "warning";
    hold = "0s";
    expr = "increase(security_log_archive_unparsed_total[10m]) > 0";
    description = "Metadata-only records were retained. Review the installed producer schema before adding allowlisted fields; never enable raw message passthrough.";
  }
]
