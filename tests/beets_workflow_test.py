"""Practical workflow tests; every media/source operation uses temporary fixtures."""

import json
import os
import io
import importlib
import errno
from contextlib import redirect_stdout
from dataclasses import replace
from pathlib import Path
import shutil
import subprocess
import unittest
from unittest.mock import patch

import beets_bulk_test as fixtures


class WorkflowTests(unittest.TestCase):
    setUp = fixtures.BulkTests.setUp
    implementation = fixtures.BulkTests.implementation
    audio = fixtures.BulkTests.audio
    metadata_implementation = fixtures.BulkTests.metadata_implementation
    approval = fixtures.BulkTests.approval
    verified_file = fixtures.BulkTests.verified_file
    publisher = fixtures.BulkTests.publisher
    catalogue_rows = fixtures.BulkTests.catalogue_rows
    native_match = fixtures.BulkTests.native_match
    bulk = fixtures.BulkTests.bulk
    ledger = fixtures.BulkTests.ledger
    fake_beet = fixtures.BulkTests.fake_beet
    arguments = fixtures.BulkTests.arguments
    supported_source = fixtures.BulkTests.supported_source
    latest_job = fixtures.BulkTests.latest_job
    next_job = fixtures.BulkTests.next_job

    def report(self, job=None):
        module = self.bulk()
        self.assertTrue(
            hasattr(module, "status_report"), "Persistent workflow status is missing"
        )
        return module.status_report(job or self.latest_job())

    def test_mixed_recursive_inputs_have_accurate_read_only_status_and_bytes(self):
        args = self.arguments()
        album = self.supported_source("nested/album/01.flac")
        alias = self.source / "backup.flac"
        shutil.copyfile(album, alias)
        loose = self.audio(
            "nested/mixed/loose.flac",
            {"artist": "Unknown", "title": "Loose"},
            frequency=880,
        )
        bad = self.source / "broken.flac"
        bad.write_bytes(b"not audio")
        originals = {p: p.read_bytes() for p in [album, alias, loose, bad]}
        self.assertEqual(self.bulk().run_bulk(args), 2)
        job = self.latest_job()
        before = (job / "bulk.sqlite3").read_bytes()
        report = self.report(job)
        statuses = {
            Path(row["source"]).name: row["status"] for row in report["sources"]
        }
        self.assertEqual(
            statuses,
            {
                "01.flac": "imported",
                "backup.flac": "imported",
                "loose.flac": "unidentified",
                "broken.flac": "failed",
            },
        )
        self.assertEqual(report["progress"]["total_files"], 4)
        self.assertEqual(
            report["progress"]["total_bytes"], sum(map(len, originals.values()))
        )
        self.assertEqual(
            report["progress"]["imported_bytes"],
            album.stat().st_size + alias.stat().st_size,
        )
        self.assertEqual((job / "bulk.sqlite3").read_bytes(), before)
        for path, contents in originals.items():
            self.assertEqual(path.read_bytes(), contents)

    def test_bounded_run_resumes_remaining_album_without_repeating_first(self):
        args = self.arguments()
        args.max_units = 1
        first = self.supported_source("a.flac", album="First")
        second = self.supported_source(
            "b.flac",
            album="Second",
            title="Second Song",
            frequency=880,
            release="11111111-1111-4111-8111-111111111111",
        )
        self.assertEqual(self.bulk().run_bulk(args), 2)
        self.assertEqual(len(self.catalogue_rows()), 1)
        report = self.report()
        self.assertEqual(report["progress"]["imported_files"], 1)
        self.assertEqual(report["progress"]["pending_files"], 1)
        self.assertEqual(report["progress"]["pending_bytes"], second.stat().st_size)
        args.resume, args.sources = self.latest_job(), []
        stage = self.implementation().stage_inputs

        def remaining(paths, *values, **kwargs):
            self.assertNotIn(first, paths)
            return stage(paths, *values, **kwargs)

        with patch("cli.stage_inputs", side_effect=remaining):
            self.assertEqual(self.bulk().run_bulk(args), 0)
        self.assertEqual(len(self.catalogue_rows()), 2)

    def test_legacy_hash_provenance_prevents_reimport_without_source_path_attribute(
        self,
    ):
        cli = self.publisher()
        file = self.verified_file()
        database = self.base / "state/library.db"
        cli.publish_verified([file], self.root, database, self.job)
        with cli.open_catalogue(database, self.root) as library:
            for item in library.items():
                del item["beets_import_source_path"]
                item.store()
        for _ in range(2):
            args = self.arguments()
            with (
                patch(
                    "cli.stage_inputs",
                    side_effect=AssertionError(
                        "Legacy imported bytes must not be staged"
                    ),
                ),
                patch(
                    "cli.run_matcher",
                    side_effect=AssertionError("Must not rematch imported content"),
                ),
            ):
                self.assertEqual(self.bulk().run_bulk(args), 0)
            self.assertEqual(self.report()["sources"][0]["status"], "imported")
        self.assertEqual(len(self.catalogue_rows()), 1)

    def test_skip_duplicate_album_keeps_unrelated_candidate(self):
        cli = self.publisher()
        first = self.verified_file()
        database = self.base / "state/library.db"
        cli.publish_verified([first], self.root, database, self.job)
        self.next_job()
        duplicate = self.verified_file("duplicate.mp3")
        album_track = self.verified_file(
            "album-02.flac", title="Album Track", track=2, frequency=660
        )
        other = self.verified_file(
            "other.flac",
            title="Other Album Song",
            album="Another Album",
            mb_albumid="11111111-1111-4111-8111-111111111111",
            frequency=880,
        )
        other = replace(other, album_key="another-album")
        files = [duplicate, album_track, other]
        with patch("builtins.input", side_effect=["l", "y"]):
            self.assertTrue(
                cli.review_publication(files, database, self.root, self.job)
            )
        self.assertEqual([file.fields["title"] for file in files], ["Other Album Song"])
        cli.publish_verified(files, self.root, database, self.job)
        self.assertEqual(len(self.catalogue_rows()), 2)
        self.assertEqual(len(cli.load_job(self.job)["skipped_candidates"]), 2)

    def test_retry_only_selected_unidentified_source(self):
        args = self.arguments()
        source = self.audio("loose.flac", {"artist": "Unknown", "title": "Loose"})
        bad = self.source / "bad.flac"
        bad.write_bytes(b"broken")
        self.assertEqual(self.bulk().run_bulk(args), 2)
        self.assertEqual(self.report()["progress"]["failed_files"], 1)
        args.retry, args.sources, args.select_sources = self.latest_job(), [], [source]
        args.auto = False

        def identified(job, sources, beet, **kwargs):
            self.assertEqual([entry.source for entry in sources], [source])
            return [self.approval(sources[0], as_album=False)]

        with (
            patch("cli.run_matcher", side_effect=identified),
            patch("builtins.input", return_value="y"),
        ):
            self.assertEqual(self.bulk().run_bulk(args), 2)
        statuses = {row["source"]: row["status"] for row in self.report()["sources"]}
        self.assertEqual(statuses, {str(source): "imported", str(bad): "failed"})

    def test_status_cli_reports_without_mutating_the_ledger(self):
        args = self.arguments()
        self.supported_source()
        self.assertEqual(self.bulk().run_bulk(args), 0)
        job = self.latest_job()
        before = (job / "bulk.sqlite3").read_bytes()
        output = io.StringIO()
        with redirect_stdout(output):
            result = self.implementation().main(
                [
                    "--library-root",
                    str(self.root),
                    "--database",
                    str(args.database),
                    "--state-directory",
                    str(args.state_directory),
                    "--status",
                    str(job),
                ]
            )
        self.assertEqual(result, 0)
        self.assertEqual(json.loads(output.getvalue())["progress"]["imported_files"], 1)
        self.assertEqual((job / "bulk.sqlite3").read_bytes(), before)

    def moving(self):
        args = self.arguments()
        args.move_after_verification = self.source
        self.assertTrue(
            (fixtures.fixtures.HELPER / "cleanup.py").exists(),
            "Journaled working-source cleanup is missing",
        )
        return args, importlib.import_module("cleanup")

    def test_move_keeps_recovery_and_duplicate_backup_sources(self):
        args, cleanup = self.moving()
        source = self.supported_source("a.flac")
        original = source.read_bytes()
        alias = self.source / "z-duplicate.flac"
        shutil.copyfile(source, alias)
        backup = self.base / "other-backup.flac"
        shutil.copyfile(source, backup)
        self.assertEqual(self.bulk().run_bulk(args), 0)
        self.assertFalse(source.exists())
        self.assertEqual(alias.read_bytes(), original)
        self.assertEqual(backup.read_bytes(), original)
        report = self.report()
        self.assertEqual(report["progress"]["moved_files"], 1)
        self.assertEqual(report["progress"]["imported_files"], 1)
        moved = next(row for row in report["sources"] if row["status"] == "moved")
        self.assertEqual(Path(moved["cleanup"]["recovery"]).read_bytes(), original)
        self.assertEqual(len(self.catalogue_rows()), 1)
        args.resume, args.sources = self.latest_job(), []
        with patch(
            "cli.run_matcher",
            side_effect=AssertionError("Completed move must not rematch"),
        ):
            self.assertEqual(self.bulk().run_bulk(args), 0)
        self.assertEqual(alias.read_bytes(), original)

    def test_move_scope_rejects_other_source_roots(self):
        args, cleanup = self.moving()
        source = self.supported_source()
        other = self.base / "backup"
        other.mkdir()
        copied = other / source.name
        shutil.copyfile(source, copied)
        args.sources.append(other)
        with patch(
            "cli.stage_inputs",
            side_effect=AssertionError("Invalid move scope must not stage"),
        ):
            self.assertEqual(self.bulk().run_bulk(args), 1)
        self.assertTrue(source.exists())
        self.assertEqual(copied.read_bytes(), source.read_bytes())

    def test_changed_source_blocks_cleanup_after_publication(self):
        args, cleanup = self.moving()
        source = self.supported_source()
        original = source.read_bytes()
        real = cleanup.run_cleanups

        def change_before_cleanup(*values, **kwargs):
            if self.implementation().catalogue_entries(args.database, self.root):
                source.write_bytes(original + b"changed")
            return real(*values, **kwargs)

        with patch("cleanup.run_cleanups", side_effect=change_before_cleanup):
            self.assertEqual(self.bulk().run_bulk(args), 2)
        self.assertEqual(source.read_bytes(), original + b"changed")
        self.assertEqual(self.report()["sources"][0]["status"], "failed")
        self.assertEqual(len(self.catalogue_rows()), 1)

    def test_changed_destination_blocks_cleanup(self):
        args, cleanup = self.moving()
        source = self.supported_source()
        real = cleanup.run_cleanups

        def change_before_cleanup(*values, **kwargs):
            for entry in self.implementation().catalogue_entries(
                args.database, self.root
            ):
                path = Path(entry["path"])
                path.write_bytes(path.read_bytes() + b"changed")
            return real(*values, **kwargs)

        with patch("cleanup.run_cleanups", side_effect=change_before_cleanup):
            self.assertEqual(self.bulk().run_bulk(args), 2)
        self.assertTrue(source.exists())
        self.assertEqual(self.report()["sources"][0]["status"], "failed")

    def test_missing_registration_never_authorizes_cleanup(self):
        args, cleanup = self.moving()
        source = self.supported_source()
        with patch("cli.register_files", return_value=None):
            self.assertEqual(self.bulk().run_bulk(args), 2)
        self.assertTrue(source.exists())
        self.assertEqual(self.report()["sources"][0]["status"], "failed")

    def test_cleanup_failure_can_retry_without_rematching(self):
        args, cleanup = self.moving()
        source = self.supported_source()
        original = source.read_bytes()
        with patch(
            "cleanup.remove_captured",
            side_effect=OSError(errno.EACCES, "simulated removal failure"),
        ):
            self.assertEqual(self.bulk().run_bulk(args), 2)
        row = self.report()["sources"][0]
        self.assertEqual(row["status"], "failed")
        self.assertEqual(Path(row["cleanup"]["captured"]).read_bytes(), original)
        args.retry, args.sources = self.latest_job(), []
        with patch(
            "cli.run_matcher",
            side_effect=AssertionError("Cleanup retry must not rematch"),
        ):
            self.assertEqual(self.bulk().run_bulk(args), 0)
        self.assertEqual(self.report()["sources"][0]["status"], "moved")
        self.assertFalse(source.exists())

    def interrupted_cleanup(self, boundary):
        args, cleanup = self.moving()
        source = self.supported_source()
        original = source.read_bytes()
        operation = getattr(cleanup, boundary)

        def interrupt(*values, **kwargs):
            operation(*values, **kwargs)
            raise KeyboardInterrupt

        with patch("cleanup." + boundary, side_effect=interrupt):
            self.assertEqual(self.bulk().run_bulk(args), 130)
        self.assertNotEqual(self.report()["sources"][0]["status"], "moved")
        source.write_bytes(b"new file at original path")
        args.resume, args.sources = self.latest_job(), []
        with patch(
            "cli.run_matcher",
            side_effect=AssertionError("Cleanup recovery must not rematch"),
        ):
            self.assertEqual(self.bulk().run_bulk(args), 0)
        self.assertEqual(source.read_bytes(), b"new file at original path")
        moved = self.report()["sources"][0]
        self.assertEqual(moved["status"], "moved")
        self.assertEqual(Path(moved["cleanup"]["recovery"]).read_bytes(), original)

    def test_cleanup_recovers_after_capture_without_removing_replacement_source(self):
        self.interrupted_cleanup("capture_source")

    def test_cleanup_recovers_after_unlink_without_removing_replacement_source(self):
        self.interrupted_cleanup("remove_captured")

    def test_missing_recovery_copy_blocks_interrupted_cleanup(self):
        args, cleanup = self.moving()
        self.supported_source()
        with patch("cleanup.remove_captured", side_effect=KeyboardInterrupt):
            self.assertEqual(self.bulk().run_bulk(args), 130)
        row = self.report()["sources"][0]
        Path(row["cleanup"]["recovery"]).unlink()
        captured = Path(row["cleanup"]["captured"])
        original = captured.read_bytes()
        args.resume, args.sources = self.latest_job(), []
        self.assertEqual(self.bulk().run_bulk(args), 2)
        self.assertEqual(captured.read_bytes(), original)
        self.assertEqual(self.report()["sources"][0]["status"], "failed")

    def test_move_previously_imported_original_without_matching_again(self):
        args = self.arguments()
        source = self.supported_source()
        self.assertEqual(self.bulk().run_bulk(args), 0)
        args, cleanup = self.moving()
        with (
            patch(
                "cli.run_matcher",
                side_effect=AssertionError(
                    "Already imported original must not rematch"
                ),
            ),
            patch(
                "cli.stage_inputs",
                side_effect=AssertionError(
                    "Already imported original must not enter matching staging"
                ),
            ),
        ):
            self.assertEqual(self.bulk().run_bulk(args), 0)
        self.assertFalse(source.exists())
        self.assertEqual(self.report()["sources"][0]["status"], "moved")

    def test_cleanup_retry_is_limited_to_selected_source(self):
        args, cleanup = self.moving()
        first = self.supported_source("a.flac", album="First")
        second = self.supported_source(
            "b.flac",
            album="Second",
            title="Second Song",
            frequency=880,
            release="11111111-1111-4111-8111-111111111111",
        )
        with patch(
            "cleanup.remove_captured",
            side_effect=OSError(errno.EACCES, "simulated removal failure"),
        ):
            self.assertEqual(self.bulk().run_bulk(args), 2)
        args.retry, args.sources, args.select_sources = self.latest_job(), [], [first]
        self.assertEqual(self.bulk().run_bulk(args), 2)
        rows = {row["source"]: row for row in self.report()["sources"]}
        self.assertEqual(rows[str(first)]["status"], "moved")
        self.assertEqual(rows[str(second)]["status"], "failed")
        self.assertTrue(Path(rows[str(second)]["cleanup"]["captured"]).exists())

    def test_retry_does_not_match_an_unselected_track_in_same_album(self):
        args = self.arguments(automatic=False)
        first = self.supported_source("a.flac")
        second = self.supported_source("b.flac", title="Second Song", frequency=880)
        with patch("cli.run_matcher", return_value=[]):
            self.assertEqual(self.bulk().run_bulk(args), 2)
        args.retry, args.sources, args.select_sources = self.latest_job(), [], [first]

        def retry_one(job, sources, beet, **kwargs):
            self.assertEqual([source.source for source in sources], [first])
            return []

        with patch("cli.run_matcher", side_effect=retry_one):
            self.assertEqual(self.bulk().run_bulk(args), 2)
        self.assertTrue(second.exists())

    def test_skipped_duplicate_remains_reviewable(self):
        cli = self.publisher()
        file = self.verified_file()
        cli.publish_verified(
            [file], self.root, self.base / "state/library.db", self.job
        )
        source = self.audio("duplicate.mp3", codec="libmp3lame")
        args = self.arguments(automatic=False)

        def match(job, sources, beet, **kwargs):
            return [self.approval(sources[0])]

        with (
            patch("cli.run_matcher", side_effect=match),
            patch("builtins.input", side_effect=["", "s"]),
        ):
            self.assertEqual(self.bulk().run_bulk(args), 2)
        args.review, args.sources = self.latest_job(), []
        self.assertEqual(
            [row["source"] for row in self.bulk().queue_entries(args.review)],
            [str(source)],
        )
        with patch(
            "builtins.input", side_effect=["r", "Alternative Version", "k", "y"]
        ):
            self.assertEqual(self.bulk().run_bulk(args), 0)
        self.assertTrue(source.exists())
        self.assertEqual(len(self.catalogue_rows()), 2)

    def test_decoder_failure_during_cleanup_is_reported_as_failed(self):
        args, cleanup = self.moving()
        source = self.supported_source()
        with patch(
            "cleanup.verify_candidate",
            side_effect=subprocess.CalledProcessError(1, ["ffmpeg"]),
        ):
            self.assertEqual(self.bulk().run_bulk(args), 2)
        self.assertTrue(source.exists())
        self.assertEqual(self.report()["sources"][0]["status"], "failed")

    @unittest.skipUnless(
        os.environ.get("BEETS_IMPORT_PACKAGE"), "Packaged CLI runs in the Nix fixture"
    )
    def test_packaged_move_and_status_commands(self):
        args = self.arguments()
        source = self.supported_source()
        original = source.read_bytes()
        command = [
            os.environ["BEETS_IMPORT_PACKAGE"],
            "--library-root",
            str(self.root),
            "--database",
            str(args.database),
            "--state-directory",
            str(args.state_directory),
            "--beet",
            args.beet,
        ]
        moved = subprocess.run(
            [
                *command,
                "--auto",
                "--max-units",
                "1",
                "--move-after-verification",
                str(self.source),
            ],
            input="",
            text=True,
            capture_output=True,
            timeout=60,
        )
        self.assertEqual(moved.returncode, 0, moved.stdout + moved.stderr)
        self.assertFalse(source.exists())
        status = subprocess.run(
            [*command, "--status", str(self.latest_job())],
            input="",
            text=True,
            capture_output=True,
            timeout=30,
        )
        self.assertEqual(status.returncode, 0, status.stderr)
        report = json.loads(status.stdout)
        self.assertEqual(report["progress"]["moved_files"], 1)
        self.assertEqual(
            Path(report["sources"][0]["cleanup"]["recovery"]).read_bytes(), original
        )

    def test_retry_cli_recovers_only_source_cleanup(self):
        args, cleanup = self.moving()
        source = self.supported_source()
        with patch(
            "cleanup.remove_captured",
            side_effect=OSError(errno.EACCES, "simulated removal failure"),
        ):
            self.assertEqual(self.bulk().run_bulk(args), 2)
        with (
            patch(
                "cli.run_matcher",
                side_effect=AssertionError("Cleanup retry must not rematch"),
            ),
            redirect_stdout(io.StringIO()),
        ):
            result = self.implementation().main(
                [
                    "--library-root",
                    str(self.root),
                    "--database",
                    str(args.database),
                    "--state-directory",
                    str(args.state_directory),
                    "--retry",
                    str(self.latest_job()),
                    "--source",
                    str(source),
                ]
            )
        self.assertEqual(result, 0)
        self.assertEqual(self.report()["sources"][0]["status"], "moved")

    def test_resume_detects_damaged_output_after_completed_move(self):
        args, cleanup = self.moving()
        source = self.supported_source()
        original = source.read_bytes()
        self.assertEqual(self.bulk().run_bulk(args), 0)
        moved = self.report()["sources"][0]
        destination = Path(moved["cleanup"]["destination"])
        destination.write_bytes(destination.read_bytes() + b"changed")
        args.resume, args.sources = self.latest_job(), []
        with patch(
            "cli.run_matcher",
            side_effect=AssertionError(
                "A damaged output needs recovery, not rematching a removed source"
            ),
        ):
            self.assertEqual(self.bulk().run_bulk(args), 2)
        self.assertEqual(self.report()["sources"][0]["status"], "failed")
        self.assertEqual(Path(moved["cleanup"]["recovery"]).read_bytes(), original)

    def test_plain_command_stages_only_one_bounded_unit(self):
        args = self.arguments(automatic=False)
        first = self.supported_source("a.flac", album="First")
        self.supported_source(
            "b.flac",
            album="Second",
            title="Second Song",
            frequency=880,
            release="11111111-1111-4111-8111-111111111111",
        )
        stage = self.implementation().stage_inputs

        def one_unit(paths, *values, **kwargs):
            self.assertEqual(
                paths, [first], "Plain imports must use bounded matching staging"
            )
            return stage(paths, *values, **kwargs)

        def match(job, sources, beet, **kwargs):
            return [self.approval(sources[0], album="First")]

        with (
            patch("cli.stage_inputs", side_effect=one_unit),
            patch("cli.run_matcher", side_effect=match),
            patch("builtins.input", side_effect=["", "y"]),
        ):
            result = self.implementation().main(
                [
                    "--library-root",
                    str(self.root),
                    "--database",
                    str(args.database),
                    "--state-directory",
                    str(args.state_directory),
                    "--max-units",
                    "1",
                    str(self.source),
                ]
            )
        self.assertEqual(result, 2)
        self.assertEqual(self.report()["progress"]["pending_files"], 1)

    def test_plain_command_skips_committed_content_before_staging(self):
        cli = self.publisher()
        file = self.verified_file()
        database = self.base / "state/library.db"
        cli.publish_verified([file], self.root, database, self.job)
        with (
            patch(
                "cli.stage_inputs",
                side_effect=AssertionError(
                    "Plain repeated imports must skip before staging"
                ),
            ),
            patch(
                "cli.run_matcher",
                side_effect=AssertionError("Must not rematch committed bytes"),
            ),
        ):
            result = cli.main(
                [
                    "--library-root",
                    str(self.root),
                    "--database",
                    str(database),
                    "--state-directory",
                    str(self.base / "state"),
                    str(self.source),
                ]
            )
        self.assertEqual(result, 0)
        self.assertEqual(self.report()["progress"]["imported_files"], 1)

    def test_retry_preserves_systemic_staging_failure(self):
        args = self.arguments()
        self.supported_source()
        with patch(
            "cli.stage_inputs",
            side_effect=OSError(errno.ENOSPC, "simulated storage failure"),
        ):
            self.assertEqual(self.bulk().run_bulk(args), 1)
        self.assertEqual(self.report()["sources"][0]["status"], "failed")
        args.retry, args.sources, args.auto = self.latest_job(), [], True
        self.assertEqual(self.bulk().run_bulk(args), 0)
        self.assertEqual(self.report()["sources"][0]["status"], "imported")

    def test_move_of_previously_imported_albums_respects_unit_budget(self):
        args = self.arguments()
        first = self.supported_source("a.flac", album="First")
        second = self.supported_source(
            "b.flac",
            album="Second",
            title="Second Song",
            frequency=880,
            release="11111111-1111-4111-8111-111111111111",
        )
        self.assertEqual(self.bulk().run_bulk(args), 0)
        args, cleanup = self.moving()
        args.max_units = 1
        self.assertEqual(self.bulk().run_bulk(args), 2)
        self.assertEqual(self.report()["progress"]["moved_files"], 1)
        self.assertEqual(self.report()["progress"]["cleanup_pending_files"], 1)
        self.assertEqual(sum(path.exists() for path in [first, second]), 1)
        args.resume, args.sources = self.latest_job(), []
        self.assertEqual(self.bulk().run_bulk(args), 0)
        self.assertEqual(self.report()["progress"]["moved_files"], 2)

    def test_later_album_track_publishes_after_an_original_was_moved(self):
        args, cleanup = self.moving()
        args.auto = False
        first = self.supported_source("a.flac")
        second = self.supported_source("b.flac", title="Second Song", frequency=880)

        def initial(job, sources, beet, **kwargs):
            return [
                self.approval(
                    next(source for source in sources if source.source == first)
                )
            ]

        with (
            patch("cli.run_matcher", side_effect=initial),
            patch("builtins.input", side_effect=["", "y"]),
        ):
            self.assertEqual(self.bulk().run_bulk(args), 2)
        self.assertFalse(first.exists())
        args.retry, args.sources, args.select_sources = self.latest_job(), [], [second]
        with (
            patch(
                "cli.run_matcher",
                side_effect=lambda job, sources, beet, **kwargs: [
                    self.approval(sources[0], title="Second Song", track=2)
                ],
            ),
            patch("builtins.input", return_value="y"),
        ):
            self.assertEqual(self.bulk().run_bulk(args), 0)
        self.assertFalse(second.exists())
        self.assertEqual(self.report()["progress"]["moved_files"], 2)
        self.assertEqual(len(self.catalogue_rows()), 2)

    def committed_status(self, boundary):
        args = self.arguments()
        source = self.supported_source()
        if boundary == "finish_unit":
            injected = patch("bulk.finish_unit", side_effect=KeyboardInterrupt)
        else:
            register = self.implementation().register_files

            def committed(*values, **kwargs):
                register(*values, **kwargs)
                raise KeyboardInterrupt

            injected = patch("cli.register_files", side_effect=committed)
        with injected:
            self.assertEqual(self.bulk().run_bulk(args), 130)
        job = self.latest_job()
        before = (job / "bulk.sqlite3").read_bytes(), args.database.read_bytes()
        report = self.report(job)
        self.assertEqual(report["sources"][0]["status"], "imported")
        self.assertEqual(report["progress"]["imported_bytes"], source.stat().st_size)
        self.assertEqual(
            ((job / "bulk.sqlite3").read_bytes(), args.database.read_bytes()), before
        )

    def test_status_recognizes_publication_before_parent_checkpoint(self):
        self.committed_status("finish_unit")

    def test_status_recognizes_catalogue_commit_before_child_checkpoint(self):
        self.committed_status("register_files")

    def recover_committed_move(self, operation):
        args, cleanup = self.moving()
        source = self.supported_source()
        original = source.read_bytes()
        cli, module = self.implementation(), self.bulk()
        register = cli.register_files

        def committed(*values, **kwargs):
            register(*values, **kwargs)
            raise KeyboardInterrupt

        with patch("cli.register_files", side_effect=committed):
            self.assertEqual(module.run_bulk(args), 130)
        job = self.latest_job()
        child = next((job / "batches").iterdir())
        self.assertEqual(cli.load_job(child)["files"][0]["status"], "published")
        self.assertEqual(source.read_bytes(), original)
        if operation == "retry":
            # Recreate the retained state left by an older helper's failed resume.
            ledger = module.BulkLedger(job, self.root, args.database)
            try:
                index = module.CommittedIndex(args.database, self.root)
                module.reconcile_committed(ledger, index)
                with ledger.connection:
                    ledger.connection.execute("UPDATE units SET status='done'")
                cleanup.run_cleanups(ledger, index)
                self.assertEqual(ledger.source_entries()[0]["outcome"], "failed")
            finally:
                ledger.close()
        setattr(args, operation, job)
        args.sources = []
        with patch(
            "cli.run_matcher",
            side_effect=AssertionError("Must replay without rematching"),
        ):
            self.assertEqual(module.run_bulk(args), 0)
        self.assertEqual(cli.load_job(child)["files"][0]["status"], "registered")
        self.assertFalse(source.exists())
        report = self.report(job)
        self.assertEqual(report["progress"]["moved_files"], 1)
        self.assertEqual(report["progress"]["cleanup_pending_files"], 0)
        self.assertEqual(
            Path(report["sources"][0]["cleanup"]["recovery"]).read_bytes(), original
        )
        self.assertEqual(len(self.catalogue_rows()), 1)

    def test_move_resume_replays_catalogue_commit_before_child_checkpoint(self):
        self.recover_committed_move("resume")

    def test_move_retry_recovers_stranded_child_checkpoint(self):
        self.recover_committed_move("retry")


if __name__ == "__main__":
    unittest.main()
