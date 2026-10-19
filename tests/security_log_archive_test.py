"""Failure-boundary tests for retained evidence, sanitization and retention."""

import io
import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from threading import Event
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

SOURCE = Path(__file__).resolve().parents[1] / "packages/security-log-archive"
sys.path.insert(0, str(SOURCE))
import archive  # noqa: E402 - Load the fixture package from the source tree.
from model import GIB, MAX_BATCH, BufferFull, Spool, encoded, normalize  # noqa: E402


def journal(message, cursor="cursor-1", unit="traefik.service", **fields):
    return {
        "__CURSOR": cursor,
        "__REALTIME_TIMESTAMP": "1792400000000000",
        "_BOOT_ID": "boot-a",
        "_SYSTEMD_UNIT": unit,
        "_UID": "0",
        "_PID": "12",
        "MESSAGE": json.dumps(message) if isinstance(message, dict) else message,
        **fields,
    }


def record(cursor="cursor-1"):
    return normalize(
        journal(
            {
                "ClientHost": "198.51.100.1",
                "RequestPath": "/probe?token=SECRET",
                "RequestMethod": "GET",
                "DownstreamStatus": 200,
            },
            cursor,
        ),
        "blizzard",
    )


class NormalizationTests(unittest.TestCase):
    def test_http_allowlist_and_peer_chain_are_preserved(self):
        result = normalize(
            journal(
                {
                    "ClientAddr": "127.0.0.1:123",
                    "ClientHost": "192.0.2.1, 2001:db8::1",
                    "RequestPath": "/probe?token=SECRET#SECRET",
                    "request_User-Agent": "test-agent",
                    "Authorization": "SECRET",
                    "request_Cookie": "SECRET",
                    "RequestBody": "SECRET",
                    "RequestMethod": "GET",
                }
            ),
            "blizzard",
        )
        self.assertNotIn("SECRET", json.dumps(result))
        self.assertEqual(result["data"]["RequestPath"], "/probe")
        self.assertEqual(result["data"]["ClientHost"], "192.0.2.1, 2001:db8::1")
        self.assertEqual(result["data"]["User-Agent"], "test-agent")

    def test_crowdsec_producer_contracts(self):
        # alerts.py emits context status strings; telemetry.go emits integer
        # remediation statuses and a separate numeric loss-report count.
        cases = [
            (
                "crowdsec-alert-archive.service",
                {
                    "event": "crowdsec_alert",
                    "kind": "local_detection",
                    "alert_id": 7,
                    "scenario": "http-probing",
                    "source_ip": "2001:db8::1",
                    "country": "NO",
                    "asn": "64500",
                    "as_name": "Example",
                    "time": "2026-10-19T12:00:00Z",
                    "events_count": 12,
                    "simulated": False,
                    "target_host": "example.test",
                    "http_method": "GET",
                    "http_status": "404",
                    "user_agent": "test-agent",
                    "target_uri": ["/one?SECRET", "/two#SECRET"],
                },
            ),
            *(
                (
                    "traefik.service",
                    {
                        "event": "crowdsec_remediation",
                        "kind": "decision",
                        "source_ip": "198.51.100.1",
                        "target_host": "example.test",
                        "target_uri": "/one?SECRET",
                        "http_method": "GET",
                        "user_agent": "test-agent",
                        "http_status": status,
                        "origin": "crowdsec",
                        "scenario": "http-probing",
                        "decision_id": 42,
                        "remediation": remediation,
                        "time": "2026-10-19T12:00:00Z",
                    },
                )
                for status, remediation in ((403, "ban"), (200, "captcha"))
            ),
            (
                "traefik.service",
                {"event": "crowdsec_remediation_log_drop", "count": 12},
            ),
        ]
        for unit, event in cases:
            result = normalize(
                journal({**event, "raw": "SECRET"}, unit=unit),
                "blizzard",
            )
            with self.subTest(event=event["event"], status=event.get("http_status")):
                self.assertEqual(result["event"], event["event"])
                self.assertNotIn("SECRET", json.dumps(result))
                for key, value in event.items():
                    if key == "target_uri":
                        paths = [value] if isinstance(value, str) else value
                        value = [p.split("?", 1)[0].split("#", 1)[0] for p in paths]
                    if key != "event":
                        self.assertEqual(result["data"][key], value)
                if "http_status" in event:
                    self.assertIs(
                        type(result["data"]["http_status"]), type(event["http_status"])
                    )

    def test_non_scalar_journal_fields_retain_only_scalar_metadata(self):
        for key in (
            "SYSLOG_IDENTIFIER",
            "_SYSTEMD_UNIT",
            "_TRANSPORT",
            "MESSAGE",
            "_BOOT_ID",
            "__REALTIME_TIMESTAMP",
            "_UID",
            "_PID",
        ):
            for value in (
                ["sudo", "SECRET"],
                [115, 117, 100, 111, 0],
                {"bad": "SECRET"},
                None,
            ):
                with self.subTest(field=key, value=value):
                    entry = journal(
                        "zeno : USER=root ; COMMAND=/bin/tool SECRET",
                        unit="user@1000.service",
                        SYSLOG_IDENTIFIER="sudo",
                    )
                    entry[key] = value
                    result = normalize(entry, "blizzard")
                    self.assertEqual(result["source"], "unparsed")
                    self.assertEqual(result["event"], "unparsed")
                    self.assertEqual(result["data"], {})
                    self.assertEqual(result["cursor"], "cursor-1")
                    self.assertNotIn("SECRET", json.dumps(result))
                    self.assertLess(len(encoded(result)), 8192)

    def test_non_scalar_event_selector_retains_metadata(self):
        for event in ([], ["crowdsec_alert"], {"bad": "SECRET"}):
            for unit in ("traefik.service", "crowdsec-alert-archive.service"):
                with self.subTest(event=event, unit=unit):
                    result = normalize(
                        journal({"event": event, "ClientHost": "SECRET"}, unit=unit),
                        "blizzard",
                    )
                    self.assertEqual(result["source"], "unparsed")
                    self.assertEqual(result["data"], {})
                    self.assertNotIn("SECRET", json.dumps(result))

    def test_authentication_and_sudo_arguments(self):
        for address in ("198.51.100.1", "2001:db8::1"):
            result = normalize(
                journal(
                    f"Accepted publickey for zeno from {address} port 1234 ssh2",
                    unit="sshd.service",
                ),
                "blizzard",
            )
            self.assertEqual(result["event"], "ssh_accepted")
            self.assertEqual(result["data"]["source_ip"], address)
        result = normalize(
            journal(
                "zeno : TTY=pts/0 ; USER=root ; COMMAND=/run/current-system/sw/bin/tool --password SECRET",
                unit="user@1000.service",
                SYSLOG_IDENTIFIER="sudo",
            ),
            "blizzard",
        )
        self.assertEqual(
            result["data"]["executable"], "/run/current-system/sw/bin/tool"
        )
        self.assertNotIn("SECRET", json.dumps(result))
        assignment = normalize(
            journal(
                "zeno : COMMAND=PASSWORD=SECRET /bin/tool",
                SYSLOG_IDENTIFIER="sudo",
                unit="user@1000.service",
            ),
            "blizzard",
        )
        self.assertNotIn("executable", assignment["data"])

    def test_kernel_and_tailscale_never_pass_through_raw_messages(self):
        entry = journal(
            'apparmor="DENIED" operation="open" profile="test" name="/file" secret="SECRET"',
            unit="",
            _TRANSPORT="kernel",
        )
        self.assertEqual(normalize(entry, "blizzard")["event"], "apparmor_denied")
        self.assertNotIn("SECRET", json.dumps(normalize(entry, "blizzard")))
        self.assertIsNone(
            normalize(
                journal("ordinary kernel message", unit="", _TRANSPORT="kernel"),
                "blizzard",
            )
        )
        tailscale = normalize(
            journal(
                "ssh-conn-123 login URL https://example.test/SECRET",
                unit="tailscaled.service",
            ),
            "blizzard",
        )
        self.assertNotIn("SECRET", json.dumps(tailscale))
        self.assertIsNone(
            normalize(
                journal("https://example.test/SECRET", unit="tailscaled.service"),
                "blizzard",
            )
        )

    def test_unknown_binary_malformed_and_large_records(self):
        for message in ("SECRET", [83, 69, 67], {"unknown": "SECRET"}):
            result = normalize(journal(message), "blizzard")
            self.assertEqual(result["source"], "unparsed")
            self.assertNotIn("SECRET", json.dumps(result))
        large = normalize(
            journal(
                {
                    "ClientHost": "::1",
                    "RequestPath": "/" + "x" * 10000,
                    "request_User-Agent": "y" * 10000,
                }
            ),
            "blizzard",
        )
        self.assertEqual(len(large["data"]["RequestPath"]), 4096)
        self.assertEqual(len(large["data"]["User-Agent"]), 1024)
        self.assertIn("RequestPath", large["truncated_fields"])

    def test_ids_survive_replay_and_distinguish_hosts(self):
        entry = journal("bad input")
        self.assertEqual(
            normalize(entry, "blizzard")["id"], normalize(entry, "blizzard")["id"]
        )
        self.assertNotEqual(
            normalize(entry, "blizzard")["id"], normalize(entry, "snowfall")["id"]
        )
        with self.assertRaises(ValueError):
            normalize({"MESSAGE": "invalid"}, "blizzard")


class SpoolTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.spool = Spool(self.root / "spool", GIB, 0)

    def test_restart_recovers_sealed_data_and_cursor(self):
        name = self.spool.append([record()], "cursor-1")
        reopened = Spool(self.spool.root, GIB, 0)
        self.assertEqual(reopened.state()["cursor"], "cursor-1")
        self.assertEqual(reopened.pending()[0][0], name)

    def test_crash_after_seal_before_checkpoint_is_recovered(self):
        with (
            patch.object(
                self.spool, "register", side_effect=RuntimeError("power loss")
            ),
            self.assertRaises(RuntimeError),
        ):
            self.spool.append([record()], "cursor-1")
        reopened = Spool(self.spool.root, GIB, 0)
        self.assertEqual(reopened.state()["cursor"], "cursor-1")
        self.assertEqual(len(reopened.pending()), 1)

    def test_crash_before_seal_never_advances_cursor(self):
        with (
            patch("model.atomic_write", side_effect=OSError("disk full")),
            self.assertRaises(OSError),
        ):
            self.spool.append([record()], "cursor-1")
        self.assertIsNone(self.spool.state().get("cursor"))
        self.assertEqual(self.spool.pending(), [])

    def test_buffer_and_filesystem_exhaustion_preserve_unsent_records(self):
        self.spool.append([record()], "cursor-1")
        self.spool.max_bytes = MAX_BATCH
        with self.assertRaises(BufferFull):
            self.spool.append([record("cursor-2")], "cursor-2")
        self.assertEqual(self.spool.state()["cursor"], "cursor-1")
        self.assertTrue(self.spool.state()["paused"])
        self.spool.max_bytes = GIB
        self.spool.min_free = 10**30
        with self.assertRaises(BufferFull):
            self.spool.append([record("cursor-2")], "cursor-2")
        self.assertEqual(len(self.spool.pending()), 1)

    def test_remote_acknowledgement_precedes_local_deletion(self):
        self.spool.append([record()], "cursor-1")
        batches = self.spool.pending()
        with (
            patch.object(self.spool, "gc", side_effect=RuntimeError("power loss")),
            self.assertRaises(RuntimeError),
        ):
            self.spool.acknowledge(batches, "a" * 64)
        reopened = Spool(self.spool.root, GIB, 0)
        self.assertEqual(reopened.pending(), [])
        self.assertEqual(reopened.state()["parent_snapshot"], "a" * 64)
        self.assertFalse(list(reopened.ready.iterdir()))

    def test_gap_and_upstream_loss_markers_survive_restart(self):
        loss = normalize(
            journal({"event": "crowdsec_remediation_log_drop", "dropped": 12}),
            "blizzard",
        )
        self.spool.append([loss], "cursor-1", now=100, gap=True)
        values = Spool(self.spool.root, GIB, 0).metric_values(now=150)
        self.assertEqual(values["gaps_total"], 1)
        self.assertEqual(values["loss_timestamp_seconds"], 100)
        self.assertEqual(values["upstream_loss_reports_total"], 1)

    def test_three_day_backlog_does_not_starve_fresh_segments(self):
        for hour in range(73):
            self.spool.append(
                [record(f"cursor-{hour}")], f"cursor-{hour}", now=hour * 3600
            )
        selected = self.spool.pending(limit=5000)
        self.assertEqual(selected[-1][1]["sealed_at"], 72 * 3600)
        self.assertEqual(selected[0][1]["sealed_at"], 0)
        self.assertEqual(
            self.spool.metric_values(now=72 * 3600)["oldest_pending_age_seconds"],
            72 * 3600,
        )

    def test_restore_verifies_hashes_and_deduplicates_replays(self):
        self.spool.append([record()], "cursor-1")
        self.spool.append([record()], "cursor-1")
        target = self.root / "restore"
        archive.stage_batch(
            self.spool, self.spool.pending(), target, {"host": "blizzard"}
        )
        output = io.BytesIO()
        archive.verify_tree(target, output)
        self.assertEqual(len(output.getvalue().splitlines()), 1)
        segment = next((target / "segments").iterdir())
        segment.write_bytes(segment.read_bytes() + b"corruption")
        with self.assertRaises(ValueError):
            archive.verify_tree(target, io.BytesIO())

    def test_metrics_remain_readable_without_access_to_payloads(self):
        target = self.root / "metrics.prom"
        old = os.umask(0o007)
        try:
            archive.write_metrics({"metrics_file": str(target)}, self.spool)
        finally:
            os.umask(old)
        self.assertEqual(target.stat().st_mode & 0o777, 0o644)
        self.assertNotIn("source_ip", target.read_text())

    def test_concurrent_metrics_publication_cannot_overwrite_newer_state(self):
        target = self.root / "metrics.prom"
        cfg = {"metrics_file": str(target)}
        self.spool.append([{"source": "unparsed"}], "cursor-1")
        newer_spool = Spool(self.spool.root, GIB, 0)
        old_sampled, release_old, newer_started, newer_published = (
            Event() for _ in range(4)
        )
        atomic_write = archive.atomic_write

        def publish(path, data, mode):
            if b"security_log_archive_unparsed_total 1\n" in data:
                old_sampled.set()
                if not release_old.wait(5):
                    raise AssertionError("older metrics writer was not released")
            else:
                newer_published.set()
            atomic_write(path, data, mode)

        def publish_newer():
            newer_started.set()
            archive.write_metrics(cfg, newer_spool)

        with (
            patch("archive.atomic_write", side_effect=publish),
            ThreadPoolExecutor(max_workers=2) as pool,
        ):
            old = pool.submit(archive.write_metrics, cfg, self.spool)
            try:
                self.assertTrue(old_sampled.wait(5))
                self.spool.append([{"source": "unparsed"}], "cursor-2")
                newer = pool.submit(publish_newer)
                self.assertTrue(newer_started.wait(5))
                self.assertFalse(newer_published.wait(0.2))
            finally:
                release_old.set()
            old.result(timeout=5)
            newer.result(timeout=5)
        self.assertIn("security_log_archive_unparsed_total 2\n", target.read_text())

    def test_conflicting_replays_cannot_silently_replace_original_evidence(self):
        original = record()
        forged = json.loads(json.dumps(original))
        forged["data"]["RequestPath"] = "/forged"
        self.spool.append([original], "cursor-1")
        self.spool.append([forged], "cursor-1")
        target = self.root / "conflicting-recovery"
        archive.stage_batch(
            self.spool, self.spool.pending(), target, {"host": "blizzard"}
        )
        with self.assertRaisesRegex(ValueError, "conflicting records"):
            archive.verify_tree(target, io.BytesIO())

    def test_database_is_writable_by_the_separate_upload_group(self):
        self.assertEqual(self.spool.db_path.stat().st_mode & 0o777, 0o660)

    def test_recovery_rejects_symlinked_metadata_and_payload_directories(self):
        self.spool.append([record()], "cursor-1")
        target = self.root / "recovery"
        archive.stage_batch(
            self.spool, self.spool.pending(), target, {"host": "blizzard"}
        )
        manifest = target / "manifest.json"
        outside = self.root / "outside-manifest.json"
        manifest.rename(outside)
        manifest.symlink_to(outside)
        with self.assertRaisesRegex(ValueError, "regular file"):
            archive.verify_tree(target, io.BytesIO())
        manifest.unlink()
        outside.rename(manifest)
        segments = target / "segments"
        outside = self.root / "outside-segments"
        segments.rename(outside)
        segments.symlink_to(outside, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "real directory"):
            archive.verify_tree(target, io.BytesIO())


class FakeRestic:
    def __init__(self, staging, fail=None):
        self.staging = staging
        self.fail = fail

    def identity(self):
        pass

    def run(self, *args, **kwargs):
        if args[0] == "backup":
            if self.fail:
                raise subprocess.CalledProcessError(self.fail, ["restic"])
            return encoded({"message_type": "summary", "snapshot_id": "a" * 64})
        if args[0] == "snapshots":
            return [{"id": "a" * 64}]
        if args[0] == "dump":
            return (self.staging / "batch/manifest.json").read_bytes()
        raise AssertionError(args)


class UploadTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.cfg = {
            "state_dir": str(self.root / "spool"),
            "staging_dir": str(self.root / "upload"),
            "buffer_bytes": GIB,
            "min_free_bytes": 0,
            "host": "blizzard",
            "metrics_file": str(self.root / "metrics.prom"),
        }
        self.spool = archive.spool_for(self.cfg)
        self.spool.append([record()], "cursor-1")

    def test_network_failure_and_incomplete_snapshot_do_not_acknowledge(self):
        for code in (1, 3):
            with self.assertRaises(subprocess.CalledProcessError):
                archive.upload(
                    self.cfg, FakeRestic(Path(self.cfg["staging_dir"]), code)
                )
            self.assertEqual(len(self.spool.pending()), 1)
            self.assertEqual(self.spool.state()["cursor"], "cursor-1")
        self.assertEqual(self.spool.state()["upload_failures"], 2)

    def test_verified_commit_is_not_undone_by_heartbeat_failure(self):
        with patch("archive.heartbeat", side_effect=OSError("network")):
            archive.upload(self.cfg, FakeRestic(Path(self.cfg["staging_dir"])))
        self.assertEqual(self.spool.pending(), [])
        self.assertEqual(self.spool.state()["heartbeat_failures"], 1)

    def test_stale_collection_cannot_report_external_success(self):
        self.spool.append([], "cursor-1", now=time.time() - 1000)
        with patch("archive.heartbeat") as beat:
            archive.upload(self.cfg, FakeRestic(Path(self.cfg["staging_dir"])))
        beat.assert_not_called()

    def test_manifest_mismatch_preserves_all_pending_data(self):
        client = FakeRestic(Path(self.cfg["staging_dir"]))
        original = client.run

        def run(*args, **kwargs):
            return b"{}" if args[0] == "dump" else original(*args, **kwargs)

        client.run = run
        with self.assertRaises(ValueError):
            archive.upload(self.cfg, client)
        self.assertEqual(len(self.spool.pending()), 1)


class HeartbeatTests(unittest.TestCase):
    def test_only_an_accepted_success_ping_counts(self):
        with tempfile.TemporaryDirectory() as directory:
            secret = Path(directory) / "heartbeat-url"
            secret.write_text(
                "https://hc-ping.com/00000000-0000-0000-0000-000000000000"
            )
            cfg = {"credentials": {"heartbeat-url": str(secret)}}
            with patch.dict(os.environ, {}, clear=True):
                for status, body, accepted in (
                    (200, b"OK", True),
                    (200, b"not found", False),
                    (429, b"rate limited", False),
                ):
                    response = MagicMock()
                    response.__enter__.return_value = response
                    response.status = status
                    response.read.return_value = body
                    with patch(
                        "archive.urllib.request.urlopen", return_value=response
                    ) as request:
                        if accepted:
                            archive.heartbeat(cfg)
                        else:
                            with self.assertRaises(RuntimeError):
                                archive.heartbeat(cfg)
                        sent = request.call_args.args[0]
                        self.assertEqual(sent.method, "POST")
                        self.assertEqual(sent.data, b"")
                secret.write_text("https://unrelated.example/private-token")
                with (
                    patch("archive.urllib.request.urlopen") as request,
                    self.assertRaises(ValueError),
                ):
                    archive.heartbeat(cfg)
                request.assert_not_called()


class CollectionTests(unittest.TestCase):
    def test_unsupported_records_seal_and_resume_without_replaying_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            cfg = {
                "state_dir": directory,
                "buffer_bytes": GIB,
                "min_free_bytes": 0,
                "host": "blizzard",
                "seal_seconds": 0,
            }
            entries = [
                journal(
                    "SECRET",
                    cursor="cursor-repeated",
                    unit="user@1000.service",
                    SYSLOG_IDENTIFIER=["sudo", "other"],
                ),
                journal(
                    "SECRET",
                    cursor="cursor-binary",
                    unit="user@1000.service",
                    SYSLOG_IDENTIFIER=[115, 117, 100, 111, 0],
                ),
                journal(
                    {"event": ["crowdsec_alert"], "raw": "SECRET"},
                    cursor="cursor-event",
                ),
                journal(
                    "Accepted publickey for zeno from 198.51.100.1 port 1234 ssh2",
                    cursor="cursor-good",
                    unit="sshd.service",
                ),
            ]

            def collect_once(batch):
                spool = archive.spool_for(cfg)
                handlers = []
                append = spool.append

                def seal(*args, **kwargs):
                    result = append(*args, **kwargs)
                    handlers[0]()
                    return result

                process = MagicMock()
                process.poll.return_value = None
                with (
                    patch("archive.spool_for", return_value=spool),
                    patch(
                        "archive.signal.signal",
                        side_effect=lambda _, handler: handlers.append(handler),
                    ),
                    patch("archive.subprocess.Popen", return_value=process) as reader,
                    patch(
                        "archive.select.select", return_value=([process.stdout], [], [])
                    ),
                    patch(
                        "archive.os.read",
                        return_value=b"".join(
                            encoded(entry) + b"\n" for entry in batch
                        ),
                    ),
                    patch.object(spool, "append", side_effect=seal),
                ):
                    archive.collect(cfg)
                return spool, reader.call_args.args[0]

            spool, _ = collect_once(entries)
            self.assertEqual(spool.state()["cursor"], "cursor-good")
            self.assertEqual(spool.metric_values()["unparsed_total"], 3)
            name, _ = spool.pending()[0]
            payload = spool.read_segment(spool.ready / name)[1]
            events = [json.loads(line) for line in payload.splitlines()]
            self.assertEqual(
                [event["source"] for event in events],
                ["unparsed"] * 3 + ["ssh", "archive"],
            )
            self.assertNotIn(b"SECRET", payload)
            next_entry = {**entries[-1], "__CURSOR": "cursor-after-restart"}
            resumed, command = collect_once([entries[-1], next_entry])
            self.assertIn("--cursor=cursor-good", command)
            self.assertEqual(resumed.state()["cursor"], "cursor-after-restart")
            self.assertEqual(resumed.metric_values()["unparsed_total"], 3)

    def test_sizing_continues_after_unsupported_selectors(self):
        entries = [
            journal(
                "SECRET", unit="user@1000.service", SYSLOG_IDENTIFIER=["sudo", "other"]
            ),
            journal({"event": {"unknown": "SECRET"}}),
            journal(
                "zeno : USER=root ; COMMAND=/bin/tool SECRET",
                unit="user@1000.service",
                SYSLOG_IDENTIFIER="sudo",
            ),
        ]
        process = MagicMock()
        process.stdout = io.BytesIO(
            b"".join(encoded(entry) + b"\n" for entry in entries)
        )
        process.wait.return_value = 0
        output = io.StringIO()
        with (
            patch("archive.subprocess.Popen", return_value=process),
            patch("archive.sys.stdout", output),
        ):
            archive.size({"host": "blizzard"}, SimpleNamespace(since="7 days ago"))
        result = json.loads(output.getvalue())
        self.assertEqual(result["records"], {"unparsed": 2, "sudo": 1})
        self.assertNotIn("SECRET", output.getvalue())

    def test_unseekable_saved_cursor_emits_a_durable_gap(self):
        with tempfile.TemporaryDirectory() as directory:
            cfg = {
                "state_dir": directory,
                "buffer_bytes": GIB,
                "min_free_bytes": 0,
                "host": "blizzard",
            }
            spool = archive.spool_for(cfg)
            spool.append([record()], "vacuumed-cursor")
            handlers = []
            append = spool.append

            def seal(*args, **kwargs):
                result = append(*args, **kwargs)
                handlers[0]()
                return result

            process = MagicMock()
            process.poll.return_value = 1
            with (
                patch("archive.spool_for", return_value=spool),
                patch(
                    "archive.signal.signal",
                    side_effect=lambda _, handler: handlers.append(handler),
                ),
                patch("archive.subprocess.Popen", return_value=process),
                patch("archive.select.select", return_value=([process.stdout], [], [])),
                patch("archive.os.read", return_value=b""),
                patch.object(spool, "append", side_effect=seal),
            ):
                archive.collect(cfg)
            state = spool.state()
            self.assertIsNone(state["cursor"])
            self.assertEqual(state["gaps"], 1)
            name, _ = spool.pending()[-1]
            payload = spool.read_segment(spool.ready / name)[1]
            self.assertEqual(json.loads(payload)["event"], "archive_gap")


class DiagnosticsTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.cfg = {
            "host": "blizzard",
            "repository_id": "a" * 64,
            "repository": "SECRET-repository",
            "admin_repository": "SECRET-admin-repository",
            "staging_dir": str(self.root / "staging"),
            "credentials": {"password": "SECRET-password-file"},
        }
        self.config = self.root / "config.json"
        self.config.write_bytes(encoded(self.cfg))

    def invoke(self, *args):
        stderr = io.StringIO()
        with (
            patch.dict(os.environ, {}, clear=True),
            patch(
                "archive.sys.argv",
                ["security-log-archive", "--config", str(self.config), *args],
            ),
            patch("archive.sys.stderr", stderr),
        ):
            status = archive.main()
        self.assertEqual(status, 1)
        diagnostic = stderr.getvalue()
        self.assertNotIn("SECRET", diagnostic)
        self.assertNotIn(str(self.root), diagnostic)
        return diagnostic

    def test_identity_interval_and_stale_plan_have_distinct_safe_reasons(self):
        with patch(
            "archive.subprocess.run",
            return_value=SimpleNamespace(stdout=encoded({"id": "b" * 64})),
        ):
            mismatch = self.invoke("inspect")
        self.assertIn(
            "phase=inspect reason=repository_id_mismatch operation=cat", mismatch
        )
        valid_identity = SimpleNamespace(stdout=encoded({"id": "a" * 64}))
        with patch("archive.subprocess.run", return_value=valid_identity):
            reversed_interval = self.invoke(
                "restore",
                "--since",
                "2026-10-19T00:00:00Z",
                "--until",
                "2026-10-18T00:00:00Z",
                "--target",
                str(self.root / "recovery"),
            )
        self.assertIn(
            "phase=restore reason=recovery_interval_reversed", reversed_interval
        )
        plan = self.root / "plan.json"
        plan.write_bytes(
            encoded(
                {
                    "version": archive.VERSION,
                    "repository_id": "a" * 64,
                    "generated_at": 0,
                    "cutoff": 0,
                }
            )
        )
        with patch("archive.subprocess.run", return_value=valid_identity):
            stale = self.invoke(
                "retention-apply", "--plan", str(plan), "--uploads-paused"
            )
        self.assertIn("phase=retention-apply reason=retention_plan_stale", stale)

    def test_backend_failures_expose_only_operation_reason_and_exit_status(self):
        for error, reason, status in (
            (
                subprocess.CalledProcessError(
                    3,
                    ["SECRET-command"],
                    output=b"SECRET-output",
                    stderr=b"SECRET-stderr",
                ),
                "backend_failed",
                " exit_status=3",
            ),
            (
                subprocess.TimeoutExpired(
                    ["SECRET-command"],
                    10,
                    output=b"SECRET-output",
                    stderr=b"SECRET-stderr",
                ),
                "backend_timeout",
                "",
            ),
            (FileNotFoundError("SECRET-path"), "backend_unavailable", ""),
        ):
            with self.subTest(reason=reason):
                with patch(
                    "archive.subprocess.run",
                    side_effect=[
                        SimpleNamespace(stdout=encoded({"id": "a" * 64})),
                        error,
                    ],
                ):
                    diagnostic = self.invoke("inspect")
                self.assertIn(
                    f"phase=inspect reason={reason} operation=stats{status}", diagnostic
                )

    def test_unexpected_errors_and_malformed_configs_do_not_leak_details(self):
        for error in (ValueError("SECRET-payload"), RuntimeError("SECRET-url")):
            with patch("archive.admin", side_effect=error):
                diagnostic = self.invoke("inspect")
            self.assertNotIn("SECRET", diagnostic)
        self.config.write_text('{"SECRET":')
        self.assertIn("phase=configuration reason=invalid_json", self.invoke("inspect"))


class RetentionTests(unittest.TestCase):
    def snapshot(self, age, identity="a", **fields):
        from datetime import datetime, timezone

        return {
            "id": identity * 64,
            "time": datetime.fromtimestamp(self.now - age, timezone.utc).isoformat(),
            "hostname": "blizzard",
            "tags": [archive.PROFILE],
            **fields,
        }

    def setUp(self):
        self.now = 1800000000

    def test_full_year_boundary(self):
        snapshots = [
            self.snapshot(archive.YEAR + 1),
            self.snapshot(archive.YEAR, "b"),
            self.snapshot(archive.YEAR - 1, "c"),
        ]
        self.assertEqual(
            archive.retention_candidates(snapshots, "blizzard", self.now), ["a" * 64]
        )

    def test_extra_snapshots_cannot_displace_valid_evidence(self):
        good = self.snapshot(100)
        garbage = [self.snapshot(age, f"{age % 10}") for age in range(200)]
        self.assertEqual(
            archive.retention_candidates([good, *garbage], "blizzard", self.now), []
        )

    def test_future_and_foreign_snapshots_abort_maintenance(self):
        for snapshot in (
            self.snapshot(-3600),
            self.snapshot(10, hostname="snowfall"),
            self.snapshot(10, tags=[]),
        ):
            with self.assertRaises(ValueError):
                archive.retention_candidates([snapshot], "blizzard", self.now)

    def test_rejected_snapshot_deletion_never_runs_prune(self):
        snapshots = [self.snapshot(archive.YEAR + 1), self.snapshot(100, "b")]
        client = MagicMock()
        client.run.side_effect = lambda *args, **_: (
            snapshots if args[0] == "snapshots" else b""
        )
        with tempfile.TemporaryDirectory() as directory:
            plan = Path(directory) / "plan.json"
            plan.write_bytes(
                encoded(
                    {
                        "version": archive.VERSION,
                        "repository_id": "c" * 64,
                        "generated_at": self.now,
                        "cutoff": self.now - archive.YEAR,
                        "snapshot_ids": ["a" * 64],
                    }
                )
            )
            args = SimpleNamespace(
                action="retention-apply", uploads_paused=True, plan=str(plan)
            )
            cfg = {"repository_id": "c" * 64, "host": "blizzard"}
            with (
                patch("archive.Restic", return_value=client),
                patch("archive.time.time", return_value=self.now),
                patch("archive.verify_tree"),
                self.assertRaises(RuntimeError),
            ):
                archive.admin(cfg, args)
        operations = [call.args[0] for call in client.run.call_args_list]
        self.assertIn("forget", operations)
        self.assertNotIn("prune", operations)


if __name__ == "__main__":
    unittest.main()
