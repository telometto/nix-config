"""Bulk import behavior against generated media and temporary catalogues."""

import hashlib
import importlib
import json
import os
import errno
from pathlib import Path
import shutil
import subprocess
import sys
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import beets_import_test as fixtures


class BulkTests(unittest.TestCase):
    setUp = fixtures.ImportTests.setUp
    implementation = fixtures.ImportTests.implementation
    audio = fixtures.ImportTests.audio
    metadata_implementation = fixtures.ImportTests.metadata_implementation
    approval = fixtures.ImportTests.approval
    verified_file = fixtures.ImportTests.verified_file
    publisher = fixtures.ImportTests.publisher
    catalogue_rows = fixtures.ImportTests.catalogue_rows
    native_match = fixtures.ImportTests.native_match

    def bulk(self):
        self.assertTrue(
            (fixtures.HELPER / "bulk.py").exists(), "bulk imports are not implemented"
        )
        return importlib.import_module("bulk")

    def ledger(self, name="inventory"):
        module = self.bulk()
        job = self.base / (".beets-import." + name)
        job.mkdir(mode=0o700)
        (job / "job.json").write_text(
            json.dumps(
                {
                    "version": 1,
                    "kind": "bulk",
                    "job": str(job),
                    "root": str(self.root),
                    "database": str(self.base / "state/library.db"),
                    "state_directory": str(self.base / "state"),
                    "source_roots": [str(self.source)],
                    "automatic": False,
                }
            )
        )
        ledger = module.BulkLedger(job, self.root, self.base / "state/library.db")
        self.addCleanup(ledger.close)
        return ledger

    def test_committed_sources_and_exact_copies_are_skipped_before_staging(self):
        verified = self.verified_file()
        self.publisher().publish_verified(
            [verified], self.root, self.base / "state/library.db", self.job
        )
        source = self.source / "song.flac"
        alias = self.source / "backup.flac"
        shutil.copyfile(source, alias)
        ledger = self.ledger()
        with patch(
            "cli.shutil.copy2",
            side_effect=AssertionError("must not stage committed bytes"),
        ):
            self.bulk().inventory_sources(ledger, [self.source])
        entries = ledger.source_entries()
        self.assertEqual(
            {row["status"] for row in entries}, {"already_imported", "exact_duplicate"}
        )
        self.assertEqual(ledger.summary()["ready"], 0)
        self.assertFalse((ledger.job / "input").exists())

    def test_exact_aliases_reference_unresolved_source(self):
        source = self.audio()
        shutil.copyfile(source, self.source / "second.flac")
        ledger = self.ledger()
        self.bulk().inventory_sources(ledger, [self.source])
        rows = ledger.source_entries()
        self.assertEqual(
            sorted(row["status"] for row in rows), ["duplicate_pending", "ready"]
        )
        representative = next(row for row in rows if row["status"] == "ready")
        alias = next(row for row in rows if row["status"] == "duplicate_pending")
        self.assertEqual(alias["duplicate_of"], representative["id"])
        self.assertEqual(ledger.summary()["committed"], 0)

    def test_inventory_resume_keeps_completed_hash_checkpoints(self):
        one = self.audio("one.flac")
        self.audio("two.flac", frequency=880)
        ledger = self.ledger()
        module = self.bulk()
        original = module.sha256
        calls = []

        def interrupt(path):
            calls.append(path)
            if len(calls) == 2:
                raise KeyboardInterrupt
            return original(path)

        with (
            patch("bulk.sha256", side_effect=interrupt),
            self.assertRaises(KeyboardInterrupt),
        ):
            module.inventory_sources(ledger, [self.source])
        self.assertEqual(ledger.summary()["inventoried"], 1)

        def remaining_only(path):
            self.assertNotEqual(path, one, "completed inventory row was rehashed")
            return original(path)

        with patch("bulk.sha256", side_effect=remaining_only):
            module.inventory_sources(ledger, [self.source])
        self.assertEqual(ledger.summary()["inventoried"], 2)

    def test_changed_canonical_output_requires_review(self):
        verified = self.verified_file()
        self.publisher().publish_verified(
            [verified], self.root, self.base / "state/library.db", self.job
        )
        (self.root / verified.relative_destination).write_bytes(b"damaged output")
        ledger = self.ledger()
        self.bulk().inventory_sources(ledger, [self.source])
        rows = ledger.source_entries()
        self.assertEqual(rows[0]["status"], "review")
        self.assertIn("output", rows[0]["reason"])
        self.assertEqual(ledger.summary()["committed"], 0)

    def test_checkpointed_staging_reuses_verified_independent_copies(self):
        cli = self.implementation()
        source = self.audio()
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        try:
            records = cli.stage_inputs(
                [source],
                self.job,
                checkpoint=True,
                expected_hashes={str(source): digest},
            )
        except TypeError:
            self.fail("staging does not support durable copy checkpoints")
        with patch(
            "cli.shutil.copy2",
            side_effect=AssertionError("verified copy must be reused"),
        ):
            repeated = cli.stage_inputs(
                [source],
                self.job,
                checkpoint=True,
                expected_hashes={str(source): digest},
            )
        self.assertEqual(repeated[0].staged, records[0].staged)
        self.assertNotEqual(source.stat().st_ino, repeated[0].staged.stat().st_ino)
        source.write_bytes(source.read_bytes() + b"changed")
        with self.assertRaisesRegex(ValueError, "changed"):
            cli.stage_inputs(
                [source],
                self.job,
                checkpoint=True,
                expected_hashes={str(source): digest},
            )

    def next_job(self, name="next"):
        self.job = self.base / (".beets-import." + name)
        self.job.mkdir(mode=0o700)
        (self.job / "job.json").write_text(
            json.dumps({"version": 1, "job": str(self.job), "root": str(self.root)})
        )

    def test_skip_one_duplicate_keeps_other_candidates(self):
        cli = self.publisher()
        first = self.verified_file()
        database = self.base / "state/library.db"
        cli.publish_verified([first], self.root, database, self.job)
        self.next_job()
        duplicate = self.verified_file("duplicate.mp3")
        unique = self.verified_file(
            "unique.flac", frequency=880, title="Other Song", track=2
        )
        files = [duplicate, unique]
        with patch("builtins.input", side_effect=["s", "y"]):
            self.assertTrue(
                cli.review_publication(files, database, self.root, self.job)
            )
        self.assertEqual([file.fields["title"] for file in files], ["Other Song"])
        cli.publish_verified(files, self.root, database, self.job)
        self.assertEqual(len(self.catalogue_rows()), 2)
        saved = json.loads((self.job / "job.json").read_text())
        self.assertEqual(
            saved["skipped_candidates"][0]["source_sha256"], duplicate.source_sha256
        )

    def test_queue_one_duplicate_continues_with_other_candidates(self):
        cli = self.publisher()
        first = self.verified_file()
        database = self.base / "state/library.db"
        cli.publish_verified([first], self.root, database, self.job)
        self.next_job()
        duplicate = self.verified_file("duplicate.mp3")
        unique = self.verified_file(
            "unique.flac", frequency=880, title="Other Song", track=2
        )
        files = [duplicate, unique]
        with patch("builtins.input", side_effect=["q", "y"]):
            self.assertTrue(
                cli.review_publication(files, database, self.root, self.job)
            )
        self.assertEqual(len(files), 1)
        saved = json.loads((self.job / "job.json").read_text())
        self.assertEqual(
            saved["review_queue"][0]["source_sha256"], duplicate.source_sha256
        )

    def policy(self):
        path = fixtures.HELPER / "beetsplug/import_policy.py"
        self.assertTrue(path.exists(), "automatic match policy is not implemented")
        specification = importlib.util.spec_from_file_location(
            "beets_bulk_policy", path
        )
        module = importlib.util.module_from_spec(specification)
        specification.loader.exec_module(module)
        return module

    def auto_task(self):
        from beets import config
        from beets.library import Item
        from beets.autotag import AlbumInfo, TrackInfo, Distance, Recommendation
        from beets.autotag.match import AlbumMatch

        config.clear()
        config.read(user=False)
        index = getattr(self, "task_counter", 0)
        self.task_counter = index + 1
        release = "f4edaaca-02e6-3746-991d-257bb7f9ad14"
        source = self.audio(
            f"policy-{index}.flac",
            {
                "artist": "Alanis Morissette",
                "album": "Jagged Little Pill",
                "title": "All I Really Want",
                "date": "1995",
                "MUSICBRAINZ_ALBUMID": release,
            },
        )
        item = Item.from_path(source)
        track = TrackInfo(
            title="All I Really Want",
            artist="Alanis Morissette",
            length=item.length,
            track_id="c5659cc0-b86b-4e2f-95f3-8d55b0d1e672",
            index=1,
            medium=1,
            medium_total=1,
            data_source="MusicBrainz",
        )
        info = AlbumInfo(
            tracks=[track],
            album="Jagged Little Pill",
            artist="Alanis Morissette",
            album_id=release,
            year=1995,
            mediums=1,
            data_source="MusicBrainz",
        )
        candidate = AlbumMatch(distance=Distance(), info=info, mapping={item: track})
        task = SimpleNamespace(
            is_album=True,
            candidates=[candidate],
            rec=Recommendation.strong,
            items=[item],
        )
        fingerprints = {item.path: ([track.track_id], [release])}
        return task, fingerprints

    def test_auto_accepts_strong_complete_fingerprinted_release(self):
        policy = self.policy()
        task, fingerprints = self.auto_task()
        choice, reason = policy.automatic_choice(task, fingerprints)
        self.assertIs(choice, task.candidates[0], reason)

    def test_auto_queues_uncertain_recordings_and_editions(self):
        policy = self.policy()
        from beets.autotag import Recommendation

        for condition in [
            "weak",
            "unknown-year",
            "missing-fingerprint",
            "ambiguous-recording",
            "incomplete",
            "edition",
            "singleton",
        ]:
            with self.subTest(condition=condition):
                task, fingerprints = self.auto_task()
                candidate = task.candidates[0]
                item = task.items[0]
                if condition == "weak":
                    task.rec = Recommendation.low
                elif condition == "unknown-year":
                    candidate.info.year = None
                elif condition == "missing-fingerprint":
                    fingerprints.clear()
                elif condition == "ambiguous-recording":
                    fingerprints[item.path][0].append(
                        "11111111-1111-4111-8111-111111111111"
                    )
                elif condition == "incomplete":
                    candidate.extra_tracks.append(candidate.info.tracks[0])
                elif condition == "edition":
                    item.mb_albumid = ""
                    fingerprints[item.path][1].append(
                        "11111111-1111-4111-8111-111111111111"
                    )
                else:
                    task.is_album = False
                choice, reason = policy.automatic_choice(task, fingerprints)
                self.assertIsNone(choice)
                self.assertTrue(reason)

    def test_auto_queues_competing_release_candidates(self):
        policy = self.policy()
        from dataclasses import replace

        task, fingerprints = self.auto_task()
        other = replace(
            task.candidates[0], info=__import__("copy").copy(task.candidates[0].info)
        )
        other.info.album_id = "11111111-1111-4111-8111-111111111111"
        task.candidates.append(other)
        choice, reason = policy.automatic_choice(task, fingerprints)
        self.assertIsNone(choice)
        self.assertIn("edition", reason)

    def test_native_auto_hook_runs_without_input_and_queues_unknown_year(self):
        release = "f4edaaca-02e6-3746-991d-257bb7f9ad14"
        source = self.audio(
            tags={
                "artist": "Alanis Morissette",
                "album": "Jagged Little Pill",
                "title": "All I Really Want",
                "date": "1995",
                "MUSICBRAINZ_ALBUMID": release,
            }
        )
        for year, count in [(1995, 1), (None, 0)]:
            with self.subTest(year=year):
                _, approvals, job = self.native_match(
                    source,
                    str(year),
                    year=year,
                    answer="",
                    automatic=True,
                    fingerprints=True,
                )
                self.assertEqual(len(approvals), count)
                events = self.implementation().read_events(job)
                self.assertTrue(
                    any(e["action"] == ("AUTO" if count else "REVIEW") for e in events)
                )

    def fake_beet(self):
        directory = self.base / "provider"
        directory.mkdir(exist_ok=True)
        (directory / "fixture_source.py").write_text("""
import uuid
from beets.metadata_plugins import MetadataSourcePlugin
from beets.autotag import AlbumInfo, TrackInfo
from beetsplug.chroma import _matches
class FixtureSourcePlugin(MetadataSourcePlugin):
    data_source = "MusicBrainz"
    def __init__(self):
        super().__init__()
        self.items = []
        self.register_listener("import_task_start", self.fingerprint)
    def recording(self, item, index=1):
        return TrackInfo(title=item.title, artist=item.artist, artists=[item.artist],
                         track_id=str(uuid.uuid5(uuid.NAMESPACE_URL, item.artist + ':' + item.title)),
                         index=index, medium=1, medium_index=index, medium_total=len(self.items),
                         length=item.length, data_source="MusicBrainz")
    def release(self):
        return self.items[0].mb_albumid or "f4edaaca-02e6-3746-991d-257bb7f9ad14"
    def fingerprint(self, session, task):
        self.items = task.items
        for item in task.items:
            _matches[item.path] = ([self.recording(item).track_id], [self.release()])
    def album_for_id(self, album_id):
        return AlbumInfo(tracks=[self.recording(item,i+1) for i,item in enumerate(self.items)],
                         album=self.items[0].album, artist=self.items[0].artist, artists=[self.items[0].artist],
                         album_id=self.release(), year=1995, mediums=1, data_source="MusicBrainz")
    def track_for_id(self, track_id):
        return self.recording(self.items[0])
    def candidates(self, items, artist, album, va_likely):
        return [self.album_for_id(None)]
    def item_candidates(self, item, artist, title):
        return [self.recording(item)]
""")
        executable = self.base / "fake-beet"
        executable.write_text(f"""#!{sys.executable} -B
import json, os
from pathlib import Path
config = Path(os.environ["BEETSDIR"]) / "config.yaml"
data = json.loads(config.read_text())
data["plugins"] = ["fixture_source", "import_audit"]
data["pluginpath"].append({str(directory)!r})
config.write_text(json.dumps(data))
import sys
with open({str(self.base / "beet-calls.jsonl")!r}, 'a') as stream:
    stream.write(json.dumps(sys.argv[1:]) + '\\n')
from beets.ui import main
main()
""")
        executable.chmod(0o700)
        return str(executable)

    def arguments(self, automatic=True):
        module = self.bulk()
        self.assertTrue(
            hasattr(module, "run_bulk"), "bulk coordinator is not implemented"
        )
        return SimpleNamespace(
            library_root=self.root,
            database=self.base / "state/library.db",
            state_directory=self.base / "state",
            sources=[self.source],
            auto=automatic,
            bulk=True,
            resume=None,
            review=None,
            queue=None,
            beet=self.fake_beet(),
            ffmpeg="ffmpeg",
            ffprobe="ffprobe",
        )

    def supported_source(
        self,
        name="known.flac",
        album="Jagged Little Pill",
        title="All I Really Want",
        frequency=440,
        release="f4edaaca-02e6-3746-991d-257bb7f9ad14",
    ):
        return self.audio(
            name,
            {
                "artist": "Alanis Morissette",
                "album": album,
                "title": title,
                "date": "1995",
                "MUSICBRAINZ_ALBUMID": release,
            },
            frequency=frequency,
        )

    def latest_job(self):
        return Path(
            json.loads((self.base / "state/latest-job.json").read_text())["job"]
        )

    def test_bulk_auto_keeps_uncertain_recording_in_queue(self):
        args = self.arguments()
        known = self.supported_source()
        unknown = self.audio(
            "loose.flac",
            {"artist": "Mystery Artist", "title": "Loose Recording"},
            frequency=880,
        )
        originals = {path: path.read_bytes() for path in [known, unknown]}
        self.assertEqual(self.bulk().run_bulk(args), 2)
        self.assertEqual(len(self.catalogue_rows()), 1)
        queue = self.bulk().queue_entries(self.latest_job())
        self.assertEqual([row["source"] for row in queue], [str(unknown)])
        self.assertTrue(queue[0]["reason"])
        for path, data in originals.items():
            self.assertEqual(path.read_bytes(), data)

    def test_bulk_operations_use_recorded_state_lock(self):
        cli, module = self.implementation(), self.bulk()
        args = self.arguments()
        self.supported_source()
        with patch("cli.stage_inputs", side_effect=KeyboardInterrupt):
            self.assertEqual(module.run_bulk(args), 130)
        job = self.latest_job()
        journal = (job / "job.json").read_bytes()
        ledger = (job / "bulk.sqlite3").read_bytes()
        state = args.state_directory
        args.state_directory, args.sources = self.base / "other-state", []
        for operation in ("resume", "review", "retry"):
            with self.subTest(operation=operation):
                setattr(args, operation, job)
                with cli.import_lock(state, str(job)):
                    self.assertEqual(module.run_bulk(args), 1)
                setattr(args, operation, None)
                self.assertEqual((job / "job.json").read_bytes(), journal)
                self.assertEqual((job / "bulk.sqlite3").read_bytes(), ledger)
                self.assertFalse(args.state_directory.exists())
        args.resume = job
        self.assertEqual(module.run_bulk(args), 0)
        self.assertFalse(args.state_directory.exists())
        self.assertEqual(len(self.catalogue_rows()), 1)

    def test_bulk_resume_does_not_repeat_committed_units(self):
        args = self.arguments()
        first = self.supported_source("a.flac", album="First Album")
        self.supported_source(
            "b.flac",
            album="Second Album",
            title="Second Song",
            frequency=880,
            release="11111111-1111-4111-8111-111111111111",
        )
        module = self.bulk()
        original = module.process_unit
        calls = []

        def interrupt(*values, **kwargs):
            calls.append(values)
            if len(calls) == 2:
                raise KeyboardInterrupt
            return original(*values, **kwargs)

        with patch("bulk.process_unit", side_effect=interrupt):
            self.assertEqual(module.run_bulk(args), 130)
        self.assertEqual(len(self.catalogue_rows()), 1)
        args.resume, args.sources = self.latest_job(), []
        real_stage = self.implementation().stage_inputs

        def stage_remaining(paths, *values, **kwargs):
            self.assertNotIn(first, paths, "committed source staged again")
            return real_stage(paths, *values, **kwargs)

        with patch("cli.stage_inputs", side_effect=stage_remaining):
            self.assertEqual(module.run_bulk(args), 0)
        self.assertEqual(len(self.catalogue_rows()), 2)

    def test_bulk_exact_alias_is_never_staged(self):
        args = self.arguments()
        first = self.supported_source()
        shutil.copyfile(first, self.source / "same-bytes.flac")
        original = self.implementation().stage_inputs

        def single_copy(paths, *values, **kwargs):
            self.assertEqual(len(paths), 1)
            return original(paths, *values, **kwargs)

        with patch("cli.stage_inputs", side_effect=single_copy):
            self.assertEqual(self.bulk().run_bulk(args), 0)
        self.assertEqual(len(self.catalogue_rows()), 1)

    def test_review_replay_only_processes_queued_sources(self):
        args = self.arguments()
        self.supported_source()
        unknown = self.audio(
            "loose.flac",
            {"artist": "Mystery Artist", "title": "Loose Recording"},
            frequency=880,
        )
        module = self.bulk()
        self.assertEqual(module.run_bulk(args), 2)
        args.review, args.sources = self.latest_job(), []

        def approve_recording(job, sources, beet, **kwargs):
            self.assertFalse(kwargs["automatic"])
            self.assertEqual([source.source for source in sources], [unknown])
            return [
                __import__("metadata").Approval(
                    sources[0].sha256,
                    {"artist": "Mystery Artist", "title": "Loose Recording"},
                    None,
                )
            ]

        with (
            patch("cli.run_matcher", side_effect=approve_recording),
            patch("builtins.input", return_value="y"),
        ):
            self.assertEqual(module.run_bulk(args), 0)
        self.assertEqual(module.queue_entries(args.review), [])
        self.assertEqual(len(self.catalogue_rows()), 2)

    def test_queue_listing_is_read_only(self):
        ledger = self.ledger()
        (self.source / "bad.ape").write_bytes(b"unsupported legacy data")
        self.bulk().inventory_sources(ledger, [self.source])
        before = (ledger.job / "bulk.sqlite3").read_bytes()
        entries = self.bulk().queue_entries(ledger.job)
        self.assertEqual(len(entries), 1)
        self.assertEqual((ledger.job / "bulk.sqlite3").read_bytes(), before)

    def test_bulk_resume_does_not_repeat_a_completed_native_choice(self):
        args = self.arguments()
        self.supported_source()
        original = self.implementation().run_matcher

        def matched_then_interrupted(*values, **kwargs):
            original(*values, **kwargs)
            raise KeyboardInterrupt

        with patch("cli.run_matcher", side_effect=matched_then_interrupted):
            self.assertEqual(self.bulk().run_bulk(args), 130)
        args.resume, args.sources = self.latest_job(), []
        self.assertEqual(self.bulk().run_bulk(args), 0)
        lines = (self.base / "beet-calls.jsonl").read_text().splitlines()
        calls = [json.loads(line) for line in lines]
        self.assertEqual(sum(call[0] == "import" for call in calls), 1)
        self.assertEqual(len(self.catalogue_rows()), 1)

    def test_bulk_resume_reuses_copy_checkpoint(self):
        args = self.arguments()
        first = self.supported_source("a.flac", title="First Song")
        self.supported_source("b.flac", title="Second Song", frequency=880)
        copy = shutil.copy2
        calls = []

        def interrupted_copy(src, dst, **kwargs):
            calls.append(Path(src))
            if len(calls) == 2:
                raise KeyboardInterrupt
            return copy(src, dst, **kwargs)

        with patch("cli.shutil.copy2", side_effect=interrupted_copy):
            self.assertEqual(self.bulk().run_bulk(args), 130)
        args.resume, args.sources = self.latest_job(), []

        def remaining_copy(src, dst, **kwargs):
            self.assertNotEqual(Path(src), first)
            return copy(src, dst, **kwargs)

        with patch("cli.shutil.copy2", side_effect=remaining_copy):
            self.assertEqual(self.bulk().run_bulk(args), 0)
        self.assertEqual(len(self.catalogue_rows()), 2)

    def test_bulk_resume_after_publication_intent(self):
        args = self.arguments()
        self.supported_source()
        link = os.link

        def stop_after_publication(src, dst, **kwargs):
            link(src, dst, **kwargs)
            if Path(dst).is_relative_to(self.root):
                raise OSError(errno.ENOSPC, "simulated storage interruption")

        with patch("cli.os.link", side_effect=stop_after_publication):
            self.assertEqual(self.bulk().run_bulk(args), 1)
        args.resume, args.sources = self.latest_job(), []
        with patch(
            "cli.run_matcher",
            side_effect=AssertionError("must recover publication without rematching"),
        ):
            self.assertEqual(self.bulk().run_bulk(args), 0)
        self.assertEqual(len(self.catalogue_rows()), 1)

    def test_review_can_correct_an_edition_label_without_rematching(self):
        args = self.arguments()
        self.supported_source("first.flac")
        module = self.bulk()
        self.assertEqual(module.run_bulk(args), 0)
        self.supported_source(
            "other-edition.flac", release="11111111-1111-4111-8111-111111111111"
        )
        self.assertEqual(module.run_bulk(args), 2)
        args.review, args.sources = self.latest_job(), []
        with (
            patch(
                "cli.run_matcher",
                side_effect=AssertionError("checked proposal should be reusable"),
            ),
            patch("builtins.input", side_effect=["r", "Live Edition", "k", "y"]),
        ):
            self.assertEqual(module.run_bulk(args), 0)
        self.assertEqual(module.queue_entries(args.review), [])
        self.assertTrue(
            (
                self.root
                / "Albums/Alanis Morissette/1995/Jagged Little Pill [Live Edition]/01-All I Really Want.flac"
            ).exists()
        )
        self.assertEqual(len(self.catalogue_rows()), 2)

    def test_resume_queues_an_exact_alias_changed_after_inventory(self):
        args = self.arguments()
        first = self.supported_source("a.flac")
        alias = self.source / "b.flac"
        shutil.copyfile(first, alias)
        module = self.bulk()
        with patch("bulk.process_unit", side_effect=KeyboardInterrupt):
            self.assertEqual(module.run_bulk(args), 130)
        alias.unlink()
        self.supported_source("b.flac", title="Different Song", frequency=880)
        changed_bytes = alias.read_bytes()
        args.resume, args.sources = self.latest_job(), []
        self.assertEqual(module.run_bulk(args), 2)
        queue = module.queue_entries(args.resume)
        self.assertEqual([entry["source"] for entry in queue], [str(alias)])
        self.assertIn("changed", queue[0]["reason"].casefold())
        self.assertEqual(len(self.catalogue_rows()), 1)
        self.assertEqual(alias.read_bytes(), changed_bytes)

    def test_resume_honors_new_skip_after_interrupted_rematch(self):
        args = self.arguments(automatic=False)
        self.supported_source()
        module = self.bulk()

        def apply(job, sources, beet, **kwargs):
            return [self.approval(sources[0])]

        with (
            patch("cli.run_matcher", side_effect=apply),
            patch("builtins.input", side_effect=["", "n"]),
        ):
            self.assertEqual(module.run_bulk(args), 2)
        args.review, args.sources = self.latest_job(), []

        def skip_then_interrupt(job, sources, beet, **kwargs):
            with (job / "decisions.jsonl").open("a") as stream:
                stream.write(
                    json.dumps(
                        {
                            "action": "SKIP",
                            "album": True,
                            "items": [
                                {"path": str(source.staged), "fields": {}}
                                for source in sources
                            ],
                        }
                    )
                    + "\n"
                )
            raise KeyboardInterrupt

        with (
            patch("cli.run_matcher", side_effect=skip_then_interrupt),
            patch("builtins.input", return_value="m"),
        ):
            self.assertEqual(module.run_bulk(args), 130)
        args.resume, args.review = args.review, None
        with patch(
            "builtins.input",
            side_effect=AssertionError("Skipped match must not reach publication"),
        ):
            self.assertEqual(module.run_bulk(args), 2)
        self.assertEqual(
            self.implementation().catalogue_entries(args.database, self.root), []
        )
        self.assertEqual(len(module.queue_entries(args.resume)), 1)

    def test_resume_retries_rematch_interrupted_before_any_new_decision(self):
        args = self.arguments(automatic=False)
        self.supported_source()
        module = self.bulk()

        def apply(job, sources, beet, **kwargs):
            approval = self.approval(sources[0])
            (job / "decisions.jsonl").write_text(
                json.dumps(
                    {
                        "action": "APPLY",
                        "album": True,
                        "items": [
                            {"path": str(sources[0].staged), "fields": approval.fields}
                        ],
                    }
                )
                + "\n"
            )
            return [approval]

        with (
            patch("cli.run_matcher", side_effect=apply),
            patch("builtins.input", side_effect=["", "n"]),
        ):
            self.assertEqual(module.run_bulk(args), 2)
        args.review, args.sources = self.latest_job(), []
        with (
            patch("cli.run_matcher", side_effect=KeyboardInterrupt),
            patch("builtins.input", return_value="m"),
        ):
            self.assertEqual(module.run_bulk(args), 130)
        args.resume, args.review, args.auto = args.review, None, True
        self.assertEqual(module.run_bulk(args), 0)
        calls = [
            json.loads(line)
            for line in (self.base / "beet-calls.jsonl").read_text().splitlines()
        ]
        self.assertEqual(sum(call[0] == "import" for call in calls), 1)

    def test_finishing_units_does_not_revisit_all_settled_sources(self):
        module = self.bulk()
        ledger = self.ledger()
        count = 40
        with ledger.connection:
            for number in range(count):
                ledger.connection.execute(
                    "INSERT INTO units(id,group_key,album,status) VALUES (?,?,0,'processing')",
                    (number + 1, str(number)),
                )
                ledger.connection.execute(
                    "INSERT INTO sources(path,sha256,status,outcome,unit_id) VALUES (?,?,'imported','imported',?)",
                    (str(self.source / f"{number}.flac"), f"{number:064x}", number + 1),
                )
        writes = []
        ledger.connection.set_trace_callback(
            lambda sql: writes.append(sql) if sql.startswith("UPDATE sources") else None
        )
        index = SimpleNamespace(
            add=lambda entries: None,
            lookup=lambda source, digest: (
                "already_imported",
                "Verified committed output",
            ),
        )
        for number in range(count):
            module.finish_unit(ledger, {"id": number + 1}, self.job, index)
        self.assertLessEqual(
            len(writes),
            count,
            "Finishing units must avoid quadratic source-status updates",
        )

    def test_review_can_continue_after_explicit_duplicate_abort(self):
        args = self.arguments()
        self.supported_source("first.flac")
        module = self.bulk()
        self.assertEqual(module.run_bulk(args), 0)
        self.supported_source(
            "other.flac", release="11111111-1111-4111-8111-111111111111"
        )
        self.assertEqual(module.run_bulk(args), 2)
        args.review, args.sources = self.latest_job(), []
        with patch("builtins.input", side_effect=["r", "Live Edition", "a"]):
            self.assertEqual(module.run_bulk(args), 130)
        with patch("builtins.input", side_effect=["r", "", "k", "y"]):
            self.assertEqual(module.run_bulk(args), 0)
        self.assertEqual(len(self.catalogue_rows()), 2)
        self.assertEqual(module.queue_entries(args.review), [])

    @unittest.skipUnless(
        os.environ.get("BEETS_IMPORT_PACKAGE"),
        "packaged CLI checked by the Nix fixture",
    )
    def test_packaged_bulk_auto_and_queue_commands(self):
        known = self.supported_source()
        unknown = self.audio(
            "loose.flac",
            {"artist": "Mystery Artist", "title": "Loose Recording"},
            frequency=880,
        )
        before = {path: path.read_bytes() for path in [known, unknown]}
        command = [
            os.environ["BEETS_IMPORT_PACKAGE"],
            "--library-root",
            str(self.root),
            "--database",
            str(self.base / "state/library.db"),
            "--state-directory",
            str(self.base / "state"),
            "--beet",
            self.fake_beet(),
        ]
        imported = subprocess.run(
            [*command, "--auto", str(self.source)],
            input="",
            text=True,
            capture_output=True,
            timeout=60,
        )
        self.assertEqual(imported.returncode, 2, imported.stdout + imported.stderr)
        self.assertEqual(len(self.catalogue_rows()), 1)
        queued = subprocess.run(
            [*command, "--queue", str(self.latest_job())],
            text=True,
            capture_output=True,
            timeout=15,
        )
        self.assertEqual(queued.returncode, 0, queued.stderr)
        self.assertEqual(
            [row["source"] for row in json.loads(queued.stdout)["review"]],
            [str(unknown)],
        )
        for path, content in before.items():
            self.assertEqual(path.read_bytes(), content)


if __name__ == "__main__":
    unittest.main()
