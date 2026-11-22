"""Recording-only policy and retry against disposable media/provider fixtures."""

import copy
import importlib.util
import json
import sys
import shutil
import os
import subprocess
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch
from contextlib import nullcontext

import beets_workflow_test as workflow
import beets_import_test as media_fixtures


RECORDING = "c5659cc0-b86b-4e2f-95f3-8d55b0d1e672"
ARTIST = "813bb97f-8c8d-4e12-8984-440925e88f03"
ACOUSTID = "3347b01e-72ec-4c28-8b45-e403367c73b0"
OTHER = "11111111-1111-4111-8111-111111111111"


class SingletonTests(unittest.TestCase):
    setUp = workflow.WorkflowTests.setUp
    implementation = workflow.WorkflowTests.implementation
    audio = workflow.WorkflowTests.audio
    metadata_implementation = workflow.WorkflowTests.metadata_implementation
    approval = workflow.WorkflowTests.approval
    verified_file = workflow.WorkflowTests.verified_file
    publisher = workflow.WorkflowTests.publisher
    catalogue_rows = workflow.WorkflowTests.catalogue_rows
    bulk = workflow.WorkflowTests.bulk
    ledger = workflow.WorkflowTests.ledger
    arguments = workflow.WorkflowTests.arguments
    supported_source = workflow.WorkflowTests.supported_source
    latest_job = workflow.WorkflowTests.latest_job
    report = workflow.WorkflowTests.report
    policy = workflow.fixtures.BulkTests.policy
    rich_metadata = media_fixtures.ImportTests.rich_metadata

    def fake_beet(self):
        directory = self.base / "recording-provider"
        directory.mkdir(exist_ok=True)
        scenario = self.base / "recording-response.json"
        if not scenario.exists():
            scenario.write_text(json.dumps(self.response()))
        trace = self.base / "recording-calls.jsonl"
        (directory / "fixture_source.py").write_text(f"""
import json
from pathlib import Path
import acoustid
from beets.metadata_plugins import MetadataSourcePlugin
from beets.autotag import TrackInfo
from beets.library import Item

def trace(event):
    with Path({str(trace)!r}).open('a') as stream:
        stream.write(json.dumps(event)+'\\n')

class FixtureSourcePlugin(MetadataSourcePlugin):
    data_source = 'MusicBrainz'
    def __init__(self):
        super().__init__()
        self.item = None
        self.register_listener('import_task_start', self.start)
        acoustid.fingerprint_file = self.fingerprint
        acoustid.lookup = self.lookup
    def start(self, task, session):
        self.item = task.items[0]
    def fingerprint(self, path):
        trace({{'event':'fingerprint'}})
        return Item.from_path(path).length, b'fixture-fingerprint'
    def lookup(self, *args, **kwargs):
        trace({{'event':'lookup'}})
        return json.loads(Path({str(scenario)!r}).read_text())
    def track_for_id(self, track_id):
        trace({{'event':'track_for_id','id':track_id}})
        return TrackInfo(title='Identified Song', artist='Known Artist', artists=['Known Artist'],
                         artist_id={ARTIST!r}, artists_ids=[{ARTIST!r}], track_id=track_id,
                         length=self.item.length, data_source='MusicBrainz',
                         album='Unproven Provider Album', year=2001)
    def item_candidates(self, item, artist, title):
        trace({{'event':'item_candidates'}})
        return []
    def album_for_id(self, album_id): return None
    def candidates(self, items, artist, album, va_likely): return []
""")
        executable = self.base / "recording-beet"
        executable.write_text(f"""#!{sys.executable} -B
import json,os
from pathlib import Path
path=Path(os.environ['BEETSDIR'])/'config.yaml'
config=json.loads(path.read_text())
config['plugins']=['fixture_source','chroma','import_audit']
config['pluginpath'].append({str(directory)!r})
path.write_text(json.dumps(config))
from beets.ui import main
main()
""")
        executable.chmod(0o700)
        return str(executable)

    def loose(self, **kwargs):
        return self.audio(
            "loose.flac",
            {"title": "00.12_2", "album": "Unverified Album", "date": "2011"},
            duration=60,
            **kwargs,
        )

    def response(self):
        return {
            "status": "ok",
            "results": [
                {
                    "id": ACOUSTID,
                    "score": 0.99,
                    "recordings": [
                        {
                            "id": RECORDING,
                            "title": "Identified Song",
                            "duration": 60,
                            "artists": [{"id": ARTIST, "name": "Known Artist"}],
                            "releases": [],
                        }
                    ],
                }
            ],
        }

    def task(self):
        from beets import config
        from beets.library import Item
        from beets.autotag import TrackInfo, Distance, Recommendation
        from beets.autotag.match import TrackMatch

        config.clear()
        config.read(user=False)
        item = Item(path=b"/fixture/00.12.flac", title="00.12", length=60.0)
        info = TrackInfo(
            title="Identified Song",
            artist="Known Artist",
            artists=["Known Artist"],
            artist_id=ARTIST,
            artists_ids=[ARTIST],
            track_id=RECORDING,
            length=60.0,
            data_source="MusicBrainz",
        )
        match = TrackMatch(Distance(), info, item)
        task = SimpleNamespace(
            is_album=False, items=[item], candidates=[match], rec=Recommendation.none
        )
        fingerprints = {item.path: ([RECORDING], [])}
        evidence = {
            item.path: {
                "duration": 60.0,
                "fingerprint_sha256": "a" * 64,
                "response": self.response(),
            }
        }
        return task, fingerprints, evidence

    def choose(self, task, fingerprints, evidence):
        policy = self.policy()
        self.assertTrue(
            hasattr(policy, "recording_choice"),
            "Recording-only acceptance policy is missing",
        )
        return policy.recording_choice(task, fingerprints, evidence)

    def test_unique_recording_with_missing_source_tags_can_use_unsorted(self):
        task, fingerprints, evidence = self.task()
        match, reason = self.choose(task, fingerprints, evidence)
        self.assertIs(match, task.candidates[0], reason)
        self.assertIsNone(match.info.album)

    def test_weak_conflicting_or_malformed_fingerprints_require_review(self):
        for condition in [
            "weak",
            "other-cluster",
            "cover",
            "unmapped",
            "wrong-cache",
            "nan",
            "invalid-id",
            "no-artists",
            "ambiguous-artists",
            "wrong-artist",
        ]:
            with self.subTest(condition=condition):
                task, fingerprints, evidence = self.task()
                payload = evidence[task.items[0].path]["response"]
                result = payload["results"][0]
                recording = result["recordings"][0]
                if condition == "weak":
                    result["score"] = 0.7
                elif condition == "other-cluster":
                    other = copy.deepcopy(result)
                    other["id"] = OTHER
                    other["score"] = 0.6
                    other["recordings"][0]["id"] = OTHER
                    payload["results"].append(other)
                elif condition == "cover":
                    other = copy.deepcopy(recording)
                    other["id"] = OTHER
                    other["artists"] = [{"id": OTHER, "name": "Original Artist"}]
                    result["recordings"].append(other)
                elif condition == "unmapped":
                    payload["results"].append({"id": OTHER, "score": 0.8})
                elif condition == "wrong-cache":
                    fingerprints[task.items[0].path] = ([OTHER], [])
                elif condition == "nan":
                    result["score"] = float("nan")
                elif condition == "invalid-id":
                    recording["id"] = "bad"
                elif condition == "no-artists":
                    recording["artists"] = []
                elif condition == "ambiguous-artists":
                    recording["artists"].append({"id": OTHER, "name": "Another Artist"})
                elif condition == "wrong-artist":
                    recording["artists"][0]["id"] = OTHER
                match, reason = self.choose(task, fingerprints, evidence)
                self.assertIsNone(match, condition)
                self.assertTrue(reason)

    def test_version_and_duration_uncertainty_require_review(self):
        for condition in [
            "live-title",
            "remaster-source",
            "disambiguation",
            "short",
            "duration",
            "mb-duration",
            "no-mbid",
            "various",
        ]:
            with self.subTest(condition=condition):
                task, fingerprints, evidence = self.task()
                item, info = task.items[0], task.candidates[0].info
                if condition == "live-title":
                    info.title += " (Live)"
                elif condition == "remaster-source":
                    item.albumdisambig = "2011 remaster"
                elif condition == "disambiguation":
                    info.trackdisambig = "different version"
                elif condition == "short":
                    evidence[item.path]["duration"] = 20.0
                elif condition == "duration":
                    evidence[item.path]["duration"] = 80.0
                elif condition == "mb-duration":
                    info.length = 70.0
                elif condition == "no-mbid":
                    info.artist_id = None
                    info.artists_ids = []
                elif condition == "various":
                    info.artist = "Various Artists"
                    info.artists = [info.artist]
                match, reason = self.choose(task, fingerprints, evidence)
                self.assertIsNone(match, condition)
                self.assertTrue(reason)

    def test_raw_lookup_keeps_competing_scores_and_calls_provider_once(self):
        path = (
            Path(self.implementation().__file__).parent
            / "beetsplug/recording_evidence.py"
        )
        self.assertTrue(path.exists(), "Raw recording-evidence collection is missing")
        spec = importlib.util.spec_from_file_location(
            "singleton_evidence_fixture", path
        )
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        response = self.response()
        response["results"].append(
            {"id": OTHER, "score": 0.7, "recordings": [{"id": OTHER}]}
        )
        from beetsplug import chroma

        lookups = []

        def lookup(*args, **kwargs):
            lookups.append((args, kwargs))
            return response

        with (
            patch.object(
                module.acoustid,
                "fingerprint_file",
                return_value=(60.0, b"fixture-fingerprint"),
            ),
            patch.object(module.acoustid, "lookup", side_effect=lookup),
        ):
            evidence = module.collect(b"/fixture/file.flac")
        self.assertEqual(evidence["response"]["results"][1]["score"], 0.7)
        self.assertEqual(len(lookups), 1)
        self.assertEqual(set(chroma._matches[b"/fixture/file.flac"][0]), {RECORDING})
        self.assertEqual(evidence["duration"], 60.0)
        self.assertEqual(len(evidence["fingerprint_sha256"]), 64)

    def child(self):
        parent = self.latest_job()
        ledger = self.bulk().BulkLedger(
            parent, self.root, self.base / "state/library.db"
        )
        try:
            return Path(
                ledger.rows(
                    "SELECT job FROM units WHERE album=0 AND job IS NOT NULL ORDER BY id"
                )[0]["job"]
            )
        finally:
            ledger.close()

    def test_native_hook_accepts_recording_without_release_or_source_artist(self):
        args = self.arguments()
        source = self.loose()
        original = source.read_bytes()
        self.assertEqual(self.bulk().run_bulk(args), 0)
        destination = self.root / "Unsorted/Known Artist/Identified Song.flac"
        self.assertTrue(destination.exists())
        self.assertEqual(source.read_bytes(), original)
        events = self.implementation().read_events(self.child())
        accepted = next(event for event in events if event["action"] == "AUTO")
        self.assertEqual(accepted["evidence"]["response"]["results"][0]["score"], 0.99)
        applied = next(event for event in events if event["action"] == "APPLY")
        self.assertEqual(applied["items"][0]["fields"]["mb_trackid"], RECORDING)
        self.assertNotIn("album", applied["items"][0]["fields"])

    def test_native_rejection_logs_conflicting_fingerprint_evidence(self):
        args = self.arguments()
        source = self.loose()
        response = self.response()
        other = copy.deepcopy(response["results"][0])
        other["id"] = OTHER
        other["recordings"][0]["id"] = OTHER
        other["score"] = 0.7
        response["results"].append(other)
        (self.base / "recording-response.json").write_text(json.dumps(response))
        self.assertEqual(self.bulk().run_bulk(args), 2)
        self.assertFalse(self.root.exists())
        event = next(
            event
            for event in self.implementation().read_events(self.child())
            if event["action"] == "REVIEW"
        )
        self.assertIn("evidence", event)
        self.assertEqual(
            event["evidence"]["response"]["results"][1]["recordings"][0]["id"], OTHER
        )
        self.assertTrue(source.exists())

    def test_existing_mbid_does_not_short_circuit_singleton_candidate_collection(self):
        args = self.arguments()
        self.audio(
            "known.flac",
            {
                "artist": "Known Artist",
                "title": "Identified Song",
                "MUSICBRAINZ_TRACKID": RECORDING,
            },
            duration=60,
        )
        self.assertEqual(self.bulk().run_bulk(args), 0)
        calls = [
            json.loads(line)["event"]
            for line in (self.base / "recording-calls.jsonl").read_text().splitlines()
        ]
        self.assertIn("item_candidates", calls)
        self.assertEqual(calls.count("lookup"), 1)

    def test_unsorted_keeps_verified_recording_ids_and_preserves_original_evidence(
        self,
    ):
        args = self.arguments()
        source = self.loose()
        self.rich_metadata(source)
        original = source.read_bytes()
        self.assertEqual(self.bulk().run_bulk(args), 0)
        from mediafile import MediaFile

        output = MediaFile(self.root / "Unsorted/Known Artist/Identified Song.flac")
        self.assertEqual(output.mb_trackid, RECORDING)
        self.assertEqual(output.mb_artistids, [ARTIST])
        self.assertFalse(output.album)
        self.assertFalse(output.year)
        self.assertFalse(output.mb_albumid)
        self.assertFalse(output.albumdisambig)
        self.assertEqual(output.comments, "Old comment")
        self.assertEqual(output.lyrics, "Existing lyrics")
        self.assertEqual(len(output.images), 1)
        self.assertEqual(source.read_bytes(), original)
        record = self.implementation().source_records(
            self.implementation().load_job(self.child())
        )[0]
        self.assertEqual(record.staged.read_bytes(), original)
        self.assertEqual(record.metadata["fields"]["album"], "Unverified Album")

    def old_queue(self, names=("a.flac", "b.flac"), album=True):
        args = self.arguments()
        for index, name in enumerate(names):
            self.audio(
                name, {"title": "00.12"}, duration=60, frequency=440 + 220 * index
            )
        if album:
            self.audio(
                "album.flac",
                {
                    "artist": "Album Artist",
                    "album": "Album requiring review",
                    "title": "Album Track",
                    "date": "1995",
                },
                duration=60,
            )

        def old_decision(job, sources, beet, **kwargs):
            with (job / "decisions.jsonl").open("a") as stream:
                stream.write(
                    json.dumps(
                        {
                            "action": "REVIEW",
                            "album": bool(sources[0].metadata["fields"].get("album")),
                            "reason": "Old recording edition policy",
                            "items": [
                                {"path": str(source.staged), "fields": {}}
                                for source in sources
                            ],
                        }
                    )
                    + "\n"
                )
                stream.write(
                    json.dumps(
                        {
                            "action": "SKIP",
                            "album": False,
                            "items": [
                                {"path": str(source.staged), "fields": {}}
                                for source in sources
                            ],
                        }
                    )
                    + "\n"
                )
            return []

        with patch("cli.run_matcher", side_effect=old_decision):
            self.assertEqual(self.bulk().run_bulk(args), 2)
        args.retry, args.sources, args.only_singletons, args.max_units = (
            self.latest_job(),
            [],
            True,
            1,
        )
        return args

    def lookup_count(self):
        path = self.base / "recording-calls.jsonl"
        return (
            sum(
                json.loads(line)["event"] == "lookup"
                for line in path.read_text().splitlines()
            )
            if path.exists()
            else 0
        )

    def test_policy_retry_is_bounded_advances_and_does_not_revisit_same_uncertainty(
        self,
    ):
        args = self.old_queue()
        response = self.response()
        response["results"][0]["score"] = 0.7
        (self.base / "recording-response.json").write_text(json.dumps(response))
        self.assertEqual(self.bulk().run_bulk(args), 2)
        rows = self.report()["sources"]
        self.assertEqual({row["status"] for row in rows}, {"unidentified"})
        self.assertEqual(self.lookup_count(), 1)
        queued = next(
            row
            for row in self.bulk().queue_entries(args.retry)
            if row["source"].endswith("a.flac")
        )
        self.assertNotIn(
            "Old recording edition policy",
            [event.get("reason") for event in queued["evidence"]],
        )
        self.assertEqual(self.bulk().run_bulk(args), 2)
        self.assertEqual(self.lookup_count(), 2)
        self.assertEqual(self.bulk().run_bulk(args), 2)
        self.assertEqual(self.lookup_count(), 2)
        self.assertIn(
            "weak",
            next(
                row["reason"]
                for row in self.report()["sources"]
                if row["source"].endswith("a.flac")
            ).casefold(),
        )
        self.assertFalse(self.root.exists())

    def test_explicit_refresh_can_reassess_provider_evidence(self):
        args = self.old_queue(names=("a.flac",), album=False)
        response = self.response()
        response["results"][0]["score"] = 0.7
        (self.base / "recording-response.json").write_text(json.dumps(response))
        self.assertEqual(self.bulk().run_bulk(args), 2)
        (self.base / "recording-response.json").write_text(json.dumps(self.response()))
        self.assertEqual(self.bulk().run_bulk(args), 2)
        self.assertEqual(self.lookup_count(), 1)
        args.refresh_evidence = True
        self.assertEqual(self.bulk().run_bulk(args), 0)
        self.assertEqual(self.lookup_count(), 2)

    def test_retry_recovers_an_interrupted_current_policy_decision_without_new_lookup(
        self,
    ):
        args = self.old_queue(names=("a.flac",), album=False)
        response = self.response()
        response["results"][0]["score"] = 0.7
        (self.base / "recording-response.json").write_text(json.dumps(response))
        matcher = self.implementation().run_matcher

        def decided_then_interrupted(*values, **kwargs):
            matcher(*values, **kwargs)
            raise KeyboardInterrupt

        with patch("cli.run_matcher", side_effect=decided_then_interrupted):
            self.assertEqual(self.bulk().run_bulk(args), 130)
        args.resume, args.retry = args.retry, None
        self.assertEqual(self.bulk().run_bulk(args), 2)
        self.assertEqual(self.lookup_count(), 1)
        args.retry, args.resume = args.resume, None
        self.assertEqual(self.bulk().run_bulk(args), 2)
        self.assertEqual(self.lookup_count(), 1)

    def test_collision_queues_without_replacing_output_or_retiring_source(self):
        args = self.arguments()
        args.move_after_verification = self.source
        source = self.loose()
        destination = self.root / "Unsorted/Known Artist/Identified Song.flac"
        destination.parent.mkdir(parents=True)
        destination.write_bytes(b"existing unrelated output")
        self.assertEqual(self.bulk().run_bulk(args), 2)
        self.assertEqual(destination.read_bytes(), b"existing unrelated output")
        self.assertTrue(source.exists())
        self.assertEqual(
            self.report()["sources"][0]["status"], "duplicate_awaiting_review"
        )

    def test_recording_only_move_keeps_independent_recovery_and_exact_alias(self):
        args = self.arguments()
        args.move_after_verification = self.source
        source = self.loose()
        original = source.read_bytes()
        alias = self.source / "z-copy.flac"
        shutil.copyfile(source, alias)
        self.assertEqual(self.bulk().run_bulk(args), 0)
        self.assertFalse(source.exists())
        self.assertEqual(alias.read_bytes(), original)
        moved = next(
            row for row in self.report()["sources"] if row["status"] == "moved"
        )
        self.assertEqual(Path(moved["cleanup"]["recovery"]).read_bytes(), original)

    @unittest.skipUnless(
        os.environ.get("BEETS_IMPORT_PACKAGE"),
        "Installed singleton retry checked by Nix fixture",
    )
    def test_packaged_helper_adopts_old_singleton_job_without_activation(self):
        args = self.old_queue(names=("a.flac",), album=False)
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
            "--retry",
            str(args.retry),
            "--only-singletons",
            "--auto",
            "--max-units",
            "1",
        ]
        result = subprocess.run(
            command, input="", text=True, capture_output=True, timeout=60
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.report()["sources"][0]["status"], "imported")
        self.assertEqual(self.lookup_count(), 1)

        result = subprocess.run(
            command, input="", text=True, capture_output=True, timeout=30
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.lookup_count(), 1)

    def test_native_source_live_at_title_is_queued(self):
        args = self.arguments()
        source = self.audio(
            "live.flac", {"title": "Identified Song live at Wembley"}, duration=60
        )
        original = source.read_bytes()
        self.assertEqual(self.bulk().run_bulk(args), 2)
        self.assertFalse(self.root.exists())
        self.assertEqual(source.read_bytes(), original)

    def test_native_provider_live_from_title_is_queued(self):
        args = self.arguments()
        source = self.loose()
        response = self.response()
        response["results"][0]["recordings"][0]["title"] = (
            "Identified Song live from Wembley"
        )
        (self.base / "recording-response.json").write_text(json.dumps(response))
        self.assertEqual(self.bulk().run_bulk(args), 2)
        self.assertFalse(self.root.exists())
        self.assertTrue(source.exists())

    def test_unsorted_clears_extra_release_identity_but_retains_recovery(self):
        args = self.arguments()
        source = self.loose()
        from mediafile import MediaFile

        media = MediaFile(source)
        release = {
            "label": "Unverified Label",
            "catalognum": "CAT-123",
            "catalognums": ["CAT-123"],
            "country": "GB",
            "albumtype": "album",
            "albumtypes": ["album"],
            "albumstatus": "official",
            "disctitle": "Disc One",
            "barcode": "1234567890123",
            "asin": "B000TEST",
            "media": "CD",
            "script": "Latn",
            "albumartist_credit": "Unverified Credit",
            "albumartist_sort": "Unverified Sort",
            "albumartists_credit": ["Unverified Credit"],
            "albumartists_sort": ["Unverified Sort"],
        }
        for field, value in release.items():
            setattr(media, field, value)
        media.save()
        original = source.read_bytes()
        self.assertEqual(self.bulk().run_bulk(args), 0)
        output = MediaFile(self.root / "Unsorted/Known Artist/Identified Song.flac")
        for field in release:
            self.assertFalse(getattr(output, field), field)
        self.assertEqual(source.read_bytes(), original)
        record = self.implementation().source_records(
            self.implementation().load_job(self.child())
        )[0]
        self.assertEqual(record.staged.read_bytes(), original)

    def test_source_disc_title_and_album_type_version_cues_are_queued(self):
        args = self.arguments()
        source = self.loose()
        from mediafile import MediaFile

        media = MediaFile(source)
        media.disctitle = "2011 remaster"
        media.albumtype = "live"
        media.save()
        self.assertEqual(self.bulk().run_bulk(args), 2)
        self.assertFalse(self.root.exists())
        self.assertTrue(source.exists())

    def retry_skips_ineligible_first(self, missing=False):
        args = self.old_queue(album=False)
        first = self.source / "a.flac"
        actual_hash = self.bulk().sha256
        if missing:
            first.unlink()
            injection = nullcontext()
        else:
            injection = patch(
                "bulk.sha256",
                side_effect=lambda path: (
                    "0" * 64 if Path(path) == first else actual_hash(path)
                ),
            )
        with injection:
            self.assertEqual(self.bulk().run_bulk(args), 2)
        rows = {Path(row["source"]).name: row for row in self.report()["sources"]}
        self.assertEqual(rows["b.flac"]["status"], "imported")
        self.assertEqual(self.lookup_count(), 1)

    def test_changed_first_source_does_not_consume_singleton_retry_budget(self):
        self.retry_skips_ineligible_first()

    def test_missing_first_source_does_not_consume_singleton_retry_budget(self):
        self.retry_skips_ineligible_first(missing=True)

    def test_durable_review_without_skip_does_not_repeat_lookup_on_resume(self):
        args = self.old_queue(names=("a.flac",), album=False)
        response = self.response()
        response["results"][0]["score"] = 0.7
        (self.base / "recording-response.json").write_text(json.dumps(response))
        matcher = self.implementation().run_matcher

        def stop_at_durable_review(job, *values, **kwargs):
            matcher(job, *values, **kwargs)
            path = job / "decisions.jsonl"
            lines = path.read_text().splitlines(keepends=True)
            end = max(
                index
                for index, line in enumerate(lines)
                if json.loads(line).get("action") == "REVIEW"
            )
            path.write_text("".join(lines[: end + 1]))
            raise KeyboardInterrupt

        with patch("cli.run_matcher", side_effect=stop_at_durable_review):
            self.assertEqual(self.bulk().run_bulk(args), 130)
        args.resume, args.retry = args.retry, None
        self.assertEqual(self.bulk().run_bulk(args), 2)
        self.assertEqual(self.lookup_count(), 1)
        args.retry, args.resume, args.refresh_evidence = args.resume, None, True
        self.assertEqual(self.bulk().run_bulk(args), 2)
        self.assertEqual(self.lookup_count(), 2)


if __name__ == "__main__":
    unittest.main()
