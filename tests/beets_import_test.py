"""Exercise guided imports using generated audio; never access a real collection."""

import hashlib
from contextlib import closing
import importlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import struct
import tempfile
import unittest
import zlib
from unittest.mock import patch


HELPER = Path(__file__).resolve().parents[1] / "home/programs/beets-import"
sys.path.insert(0, str(HELPER))


class ImportTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="beets-test-")
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.source = self.base / "sources"
        self.source.mkdir()
        self.job = self.base / ".beets-import.test"
        self.job.mkdir(mode=0o700)
        self.root = self.base / "library"
        environment = patch.dict(
            os.environ,
            {
                "XDG_CONFIG_HOME": str(self.base / "xdg/config"),
                "XDG_CACHE_HOME": str(self.base / "xdg/cache"),
                "XDG_DATA_HOME": str(self.base / "xdg/data"),
                "XDG_STATE_HOME": str(self.base / "xdg/state"),
            },
        )
        environment.start()
        self.addCleanup(environment.stop)
        (self.job / "job.json").write_text(
            json.dumps({"version": 1, "root": str(self.root), "job": str(self.job)})
        )

    def implementation(self):
        self.assertTrue(
            (HELPER / "cli.py").is_file(), "guided import is not implemented"
        )
        return importlib.import_module("cli")

    def audio(
        self, name="song.flac", tags=None, codec="flac", frequency=440, duration=0.08
    ):
        path = self.source / name
        path.parent.mkdir(parents=True, exist_ok=True)
        args = [
            "ffmpeg",
            "-v",
            "error",
            "-f",
            "lavfi",
            "-i",
            f"sine=frequency={frequency}:duration={duration}",
            "-c:a",
            codec,
        ]
        for key, value in (tags or {}).items():
            args.extend(["-metadata", f"{key}={value}"])
        subprocess.run([*args, str(path)], check=True, capture_output=True)
        return path

    def test_staging_is_independent(self):
        cli = self.implementation()
        source = self.audio()
        before = source.read_bytes()
        records = cli.stage_inputs([source], self.job)
        self.assertEqual(len(records), 1)
        self.assertEqual(records[0].staged.read_bytes(), before)
        self.assertEqual(source.read_bytes(), before)
        self.assertNotEqual(source.stat().st_ino, records[0].staged.stat().st_ino)
        self.assertEqual(records[0].sha256, hashlib.sha256(before).hexdigest())

    def test_overlapping_sources_and_links_are_refused(self):
        cli = self.implementation()
        source = self.audio()
        link = self.source / "linked.flac"
        link.symlink_to(source)
        for paths in ([link], [self.base], [self.source, source]):
            with self.subTest(paths=paths), self.assertRaises(ValueError):
                cli.stage_inputs(paths, self.job)
        self.assertTrue(source.exists())
        self.assertFalse(self.root.exists())

    def test_source_changed_during_copy_is_pending(self):
        cli = self.implementation()
        source = self.audio()
        real_copy = shutil.copy2

        def external_change(src, dst, **kwargs):
            result = real_copy(src, dst, **kwargs)
            Path(src).write_bytes(Path(src).read_bytes() + b"external change")
            return result

        with patch("cli.shutil.copy2", side_effect=external_change):
            with self.assertRaisesRegex(ValueError, "changed"):
                cli.stage_inputs([source], self.job)
        self.assertFalse(self.root.exists())

    def test_mixed_folder_splits_album_groups(self):
        cli = self.implementation()
        sources = [
            self.audio("a.flac", {"artist": "First", "album": "One"}),
            self.audio("b.flac", {"artist": "First", "album": "One"}),
            self.audio("c.flac", {"artist": "Second", "album": "Two"}),
            self.audio("unknown1.flac"),
            self.audio("unknown2.flac"),
        ]
        groups = cli.partition_sources(cli.stage_inputs(sources, self.job))
        self.assertEqual(sorted(len(g[1]) for g in groups if g[0]), [1, 2])
        self.assertEqual(sorted(len(g[1]) for g in groups if not g[0]), [1, 1])

    def test_apply_is_required_for_publication(self):
        cli = self.implementation()
        records = cli.stage_inputs([self.audio()], self.job)
        path = str(records[0].staged)
        events = [
            {
                "action": action,
                "album": False,
                "items": [
                    {"path": path, "fields": {"artist": "Artist", "title": "Title"}}
                ],
            }
            for action in ["ASIS", "SKIP", "APPLY"]
        ]
        self.assertEqual(cli.read_approvals(events[:2], records), [])
        approved = cli.read_approvals(events, records)
        self.assertEqual(len(approved), 1)
        self.assertEqual(approved[0].fields["artist"], "Artist")

    def test_matcher_environment_is_isolated(self):
        cli = self.implementation()
        cfg, env = cli.matcher_configuration(self.job)
        self.assertEqual(env["BEETSDIR"], str(self.job / "config"))
        self.assertEqual(cfg["library"], str(self.job / "matching.db"))
        self.assertTrue(cfg["import"]["timid"])
        self.assertFalse(cfg["import"]["quiet"])
        for name in ["copy", "move", "write", "link", "hardlink", "reflink"]:
            self.assertFalse(cfg["import"][name], name)
        self.assertEqual(cfg["plugins"], ["musicbrainz", "chroma", "import_audit"])
        self.assertNotIn("match", cfg)
        self.assertTrue(str(cfg["statefile"]).startswith(str(self.job)))

    def metadata_implementation(self):
        self.implementation()
        module = importlib.import_module("metadata")
        self.assertTrue(
            hasattr(module, "prepare_candidate"), "selective writer is not implemented"
        )
        return module

    def approval(self, record, as_album=True, **changes):
        module = importlib.import_module("metadata")
        fields = {"artist": "Alanis Morissette", "title": "All I Really Want"}
        if as_album:
            fields.update(
                {
                    "albumartist": "Alanis Morissette",
                    "album": "Jagged Little Pill",
                    "year": 1995,
                    "track": 1,
                    "tracktotal": 13,
                    "disc": 1,
                    "disctotal": 1,
                    "mb_albumid": "f4edaaca-02e6-3746-991d-257bb7f9ad14",
                }
            )
        fields.update(changes)
        return module.Approval(record.sha256, fields, "album" if as_album else None)

    def rich_metadata(self, path):
        from mediafile import MediaFile, Image, ImageType
        from mutagen.id3 import POPM, TXXX

        def chunk(kind, data):
            return (
                struct.pack("!I", len(data))
                + kind
                + data
                + struct.pack("!I", zlib.crc32(kind + data))
            )

        png = (
            b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack("!IIBBBBB", 1, 1, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(b"\x00\xff\x00\x00\xff"))
            + chunk(b"IEND", b"")
        )
        media = MediaFile(path)
        media.composers = ["Glen Ballard", "Alanis Morissette"]
        media.composer_sort = "Ballard, Glen;Morissette, Alanis"
        media.comments = "Old comment"
        media.lyrics = "Existing lyrics"
        media.rg_track_gain = -5.25
        media.images = [Image(png, desc="original cover", type=ImageType.front)]
        media.save()
        media = MediaFile(path)
        if media.type == "mp3":
            media.mgfile.tags.add(POPM(email="old-player", rating=230, count=19))
            media.mgfile.tags.add(
                TXXX(encoding=3, desc="PRIVATE-OLD-TAG", text=["keep"])
            )
        elif media.type in {"aac", "alac"}:
            media.mgfile.tags["----:com.apple.iTunes:PRIVATE-OLD-TAG"] = [b"keep"]
        else:
            media.mgfile.tags["RATING"] = ["230"]
            media.mgfile.tags["PRIVATE-OLD-TAG"] = ["keep"]
        media.mgfile.save()

    def test_selective_identity_write_preserves_extra_tags(self):
        metadata = self.metadata_implementation()
        cli = self.implementation()
        for name, codec in [
            ("rich.flac", "flac"),
            ("rich.mp3", "libmp3lame"),
            ("rich.m4a", "aac"),
            ("rich-alac.m4a", "alac"),
        ]:
            with self.subTest(format=name):
                path = self.audio(name, codec=codec)
                self.rich_metadata(path)
                before = path.read_bytes()
                record = cli.stage_inputs([path], self.job)[0]
                approval = self.approval(
                    record, composer="WRONG PROVIDER CREDIT", bpm=0
                )
                candidate = metadata.prepare_candidate(record, approval, self.job)
                verified = metadata.verify_candidate(record, candidate, approval)
                from mediafile import MediaFile

                result = MediaFile(candidate)
                self.assertEqual(
                    result.composer_sort, "Ballard, Glen;Morissette, Alanis"
                )
                self.assertEqual(
                    result.composers, ["Glen Ballard", "Alanis Morissette"]
                )
                self.assertEqual(result.lyrics, "Existing lyrics")
                self.assertEqual(result.comments, "Old comment")
                self.assertEqual(result.title, "All I Really Want")
                self.assertEqual(path.read_bytes(), before)
                self.assertTrue(verified["pcm_sha256"])
                self.assertTrue(verified["packet_sha256"])

    def test_untagged_unsorted_adds_only_confirmed_identity(self):
        metadata = self.metadata_implementation()
        path = self.audio(
            tags={
                "acoustid_id": "original-acoustid",
                "album": "Unverified",
                "date": "2000",
            }
        )
        record = self.implementation().stage_inputs([path], self.job)[0]
        approval = self.approval(
            record, as_album=False, artist="John Frusciante", title="Twenty Four Hours"
        )
        candidate = metadata.prepare_candidate(record, approval, self.job)
        metadata.verify_candidate(record, candidate, approval)
        from mediafile import MediaFile

        media = MediaFile(candidate)
        self.assertEqual(media.artist, "John Frusciante")
        self.assertEqual(media.title, "Twenty Four Hours")
        tags = {k.casefold(): v for k, v in media.mgfile.tags.items()}
        self.assertEqual(tags["acoustid_id"], ["original-acoustid"])
        self.assertNotIn("album", tags)
        self.assertFalse(
            set(tags) & {"date", "year", "track", "disc", "bpm", "compilation"}
        )
        self.assertEqual(
            metadata.plan_destination(approval, candidate),
            Path("Unsorted/John Frusciante/Twenty Four Hours.flac"),
        )

    def test_unexpected_metadata_or_audio_change_blocks_candidate(self):
        metadata = self.metadata_implementation()
        path = self.audio(tags={"comment": "Keep me"})
        record = self.implementation().stage_inputs([path], self.job)[0]
        approval = self.approval(record)
        candidate = metadata.prepare_candidate(record, approval, self.job)
        from mediafile import MediaFile

        media = MediaFile(candidate)
        media.comments = "Lost old comment"
        media.save()
        with self.assertRaisesRegex(ValueError, "metadata"):
            metadata.verify_candidate(record, candidate, approval)
        other = self.audio("other.flac", {"comment": "Keep me"}, frequency=880)
        other_record = self.implementation().stage_inputs([other], self.job)[0]
        other_candidate = metadata.prepare_candidate(
            other_record, self.approval(other_record), self.job
        )
        shutil.copyfile(other_candidate, candidate)
        with self.assertRaisesRegex(ValueError, "Audio"):
            metadata.verify_candidate(record, candidate, approval)

    def test_zero_placeholder_is_rejected(self):
        metadata = self.metadata_implementation()
        record = self.implementation().stage_inputs([self.audio()], self.job)[0]
        approval = self.approval(record, as_album=False)
        candidate = metadata.prepare_candidate(record, approval, self.job)
        from mediafile import MediaFile

        media = MediaFile(candidate)
        media.mgfile.tags["DATE"] = ["0000"]
        media.mgfile.save()
        with self.assertRaisesRegex(ValueError, "metadata"):
            metadata.verify_candidate(record, candidate, approval)

    def test_mp4_custom_atom_type_is_preserved(self):
        metadata = self.metadata_implementation()
        source = self.audio("atom.m4a", codec="aac")
        self.rich_metadata(source)
        record = self.implementation().stage_inputs([source], self.job)[0]
        approval = self.approval(record)
        candidate = metadata.prepare_candidate(record, approval, self.job)
        from mediafile import MediaFile
        from mutagen.mp4 import AtomDataType, MP4FreeForm

        media = MediaFile(candidate)
        media.mgfile.tags["----:com.apple.iTunes:PRIVATE-OLD-TAG"] = [
            MP4FreeForm(b"keep", dataformat=AtomDataType.IMPLICIT)
        ]
        media.save()
        with self.assertRaisesRegex(ValueError, "metadata"):
            metadata.verify_candidate(record, candidate, approval)

    def test_id3v23_preserved(self):
        metadata = self.metadata_implementation()
        source = self.audio(
            "old.mp3", {"comment": "Old player comment"}, codec="libmp3lame"
        )
        from mediafile import MediaFile

        media = MediaFile(source, id3v23=True)
        media.save()
        record = self.implementation().stage_inputs([source], self.job)[0]
        approval = self.approval(record)
        candidate = metadata.prepare_candidate(record, approval, self.job)
        metadata.verify_candidate(record, candidate, approval)
        self.assertEqual(MediaFile(candidate).mgfile.tags.version, (2, 3, 0))

    def test_album_compilation_edition_paths(self):
        metadata = self.metadata_implementation()
        from dataclasses import replace

        record = self.implementation().stage_inputs([self.audio()], self.job)[0]
        approval = self.approval(record)
        self.assertEqual(
            metadata.plan_destination(approval, Path("file.flac")),
            Path(
                "Albums/Alanis Morissette/1995/Jagged Little Pill/01-All I Really Want.flac"
            ),
        )
        compilation = self.approval(record, comp=True, album="Collection")
        self.assertEqual(
            metadata.plan_destination(compilation, Path("file.flac")),
            Path("Albums/Various Artists/1995/Collection/01-All I Really Want.flac"),
        )
        edition = replace(approval, edition="Deluxe Edition")
        self.assertEqual(
            metadata.plan_destination(edition, Path("file.flac")),
            Path(
                "Albums/Alanis Morissette/1995/Jagged Little Pill [Deluxe Edition]/01-All I Really Want.flac"
            ),
        )

    def test_multidisc_uses_continuous_track_numbers(self):
        metadata = self.metadata_implementation()
        cli = self.implementation()
        record = cli.stage_inputs([self.audio()], self.job)[0]
        self.assertFalse(cli.matcher_configuration(self.job)[0]["per_disc_numbering"])
        approval = self.approval(record, disc=2, disctotal=2, track=4, tracktotal=6)
        self.assertEqual(
            metadata.plan_destination(approval, Path("f.flac")).name,
            "04-All I Really Want.flac",
        )
        self.assertEqual(
            len(metadata.plan_destination(approval, Path("f.flac")).parts), 5
        )

    def test_unknown_release_year_remains_pending(self):
        metadata = self.metadata_implementation()
        record = self.implementation().stage_inputs([self.audio()], self.job)[0]
        with self.assertRaisesRegex(ValueError, "year"):
            metadata.plan_destination(self.approval(record, year=0), Path("f.flac"))
        self.assertFalse(self.root.exists())

    def test_sanitized_paths_stay_inside_root(self):
        metadata = self.metadata_implementation()
        record = self.implementation().stage_inputs([self.audio()], self.job)[0]
        approval = self.approval(
            record,
            artist="../../escape",
            albumartist="../../escape",
            album="../name",
            title="a/b:?",
        )
        result = metadata.plan_destination(approval, Path("f.flac"))
        self.assertFalse(result.is_absolute())
        self.assertNotIn("..", result.parts)
        self.assertEqual(len(result.parts), 5)

    def test_unsupported_legacy_tags_are_pending(self):
        metadata = self.metadata_implementation()
        with self.assertRaisesRegex(ValueError, "metadata"):
            metadata.normalise_tag(object())

    def verified_file(self, name="song.flac", as_album=True, frequency=440, **fields):
        metadata = self.metadata_implementation()
        cli = self.implementation()
        source = self.audio(
            name,
            codec="libmp3lame" if name.endswith(".mp3") else "flac",
            frequency=frequency,
        )
        record = cli.stage_inputs([source], self.job)[0]
        approval = self.approval(record, as_album=as_album, **fields)
        candidate = metadata.prepare_candidate(record, approval, self.job)
        verification = metadata.verify_candidate(record, candidate, approval)
        from dataclasses import asdict

        journal = json.loads((self.job / "job.json").read_text())
        journal.setdefault("sources", []).append(asdict(record))
        (self.job / "job.json").write_text(json.dumps(journal, default=str))
        return metadata.VerifiedFile(
            record.sha256,
            candidate,
            metadata.plan_destination(approval, candidate),
            {**approval.fields, "edition": approval.edition},
            approval.album_key,
            verification,
        )

    def publisher(self):
        cli = self.implementation()
        self.assertTrue(
            hasattr(cli, "publish_verified"), "checked publication is not implemented"
        )
        return cli

    def catalogue_rows(self):
        import sqlite3

        with closing(sqlite3.connect(self.base / "state/library.db")) as db:
            return db.execute(
                "select title, album_id from items order by id"
            ).fetchall()

    def test_existing_destination_is_never_replaced(self):
        cli = self.publisher()
        verified = self.verified_file()
        destination = self.root / verified.relative_destination
        destination.parent.mkdir(parents=True)
        destination.write_bytes(b"existing user file")
        with self.assertRaisesRegex(ValueError, "destination"):
            cli.publish_verified(
                [verified], self.root, self.base / "state/library.db", self.job
            )
        self.assertEqual(destination.read_bytes(), b"existing user file")
        self.assertFalse((self.base / "state/library.db").exists())

    def test_duplicate_candidates_require_review(self):
        cli = self.publisher()
        first = self.verified_file()
        cli.publish_verified(
            [first], self.root, self.base / "state/library.db", self.job
        )
        self.job = self.base / ".beets-import.next"
        self.job.mkdir(mode=0o700)
        (self.job / "job.json").write_text(
            json.dumps({"version": 1, "root": str(self.root), "job": str(self.job)})
        )
        second = self.verified_file("second.mp3")
        with self.assertRaisesRegex(ValueError, "duplicate"):
            cli.publish_verified(
                [second], self.root, self.base / "state/library.db", self.job
            )
        self.assertEqual(len(self.catalogue_rows()), 1)
        from dataclasses import replace

        self.assertTrue(
            cli.find_duplicates(
                [first, replace(first, relative_destination=Path("other"))], []
            )
        )
        distinct = self.verified_file(
            "third.flac",
            album="Live Collection",
            mb_albumid="6adff1fe-7f2f-4d37-a67c-d67f3c7a5d13",
        )
        self.assertTrue(
            cli.find_duplicates(
                [distinct],
                cli.catalogue_entries(self.base / "state/library.db", self.root),
            )
        )

    def test_two_imports_cannot_publish_concurrently(self):
        cli = self.publisher()
        state = self.base / "state"
        with cli.import_lock(state, str(self.job)):
            with self.assertRaisesRegex(ValueError, str(self.job)):
                with cli.import_lock(state, "second-job"):
                    self.fail("second import acquired the lock")

    def test_resume_after_publication_before_registration(self):
        cli = self.publisher()
        verified = self.verified_file()
        real_link = os.link

        def interrupted_link(src, dst, **kwargs):
            real_link(src, dst, **kwargs)
            raise OSError("simulated interruption after publication")

        with (
            patch("cli.os.link", side_effect=interrupted_link),
            self.assertRaises(OSError),
        ):
            cli.publish_verified(
                [verified], self.root, self.base / "state/library.db", self.job
            )
        result = cli.resume_job(self.job)
        self.assertEqual(result["registered"], 1)
        self.assertEqual(len(self.catalogue_rows()), 1)
        self.assertEqual(cli.resume_job(self.job)["registered"], 1)
        self.assertEqual(len(self.catalogue_rows()), 1)
        self.assertTrue(self.catalogue_rows()[0][1])

    def test_resume_after_database_commit(self):
        cli = self.publisher()
        verified = self.verified_file(as_album=False)
        original = cli.register_files

        def commit_then_interrupt(*args, **kwargs):
            original(*args, **kwargs)
            raise OSError("simulated interruption after database commit")

        with (
            patch("cli.register_files", side_effect=commit_then_interrupt),
            self.assertRaises(OSError),
        ):
            cli.publish_verified(
                [verified], self.root, self.base / "state/library.db", self.job
            )
        self.assertEqual(len(self.catalogue_rows()), 1)
        self.assertEqual(cli.resume_job(self.job)["registered"], 1)
        self.assertEqual(self.catalogue_rows(), [("All I Really Want", None)])

    def test_disk_or_database_failure_reports_incomplete_job(self):
        cli = self.publisher()
        verified = self.verified_file()
        with (
            patch("cli.os.link", side_effect=OSError("No space left")),
            self.assertRaises(OSError),
        ):
            cli.publish_verified(
                [verified], self.root, self.base / "state/library.db", self.job
            )
        self.assertTrue(verified.candidate.exists())
        self.assertFalse((self.root / verified.relative_destination).exists())
        self.assertEqual(
            json.loads((self.job / "job.json").read_text())["files"][0]["status"],
            "publishing",
        )
        self.assertEqual(cli.resume_job(self.job)["registered"], 1)

    def test_registration_failure_rolls_back_album(self):
        cli = self.publisher()
        first = self.verified_file()
        second = self.verified_file(
            "other.flac",
            frequency=880,
            album="Other Album",
            title="Other Song",
            mb_albumid="6adff1fe-7f2f-4d37-a67c-d67f3c7a5d13",
        )
        from dataclasses import replace

        second = replace(second, album_key="other-album")
        from beets.library import Library

        real_add = Library.add_album
        calls = []

        def add_then_fail(library, items):
            calls.append(items)
            if len(calls) == 2:
                raise OSError("database error")
            return real_add(library, items)

        with (
            patch.object(Library, "add_album", new=add_then_fail),
            self.assertRaises(OSError),
        ):
            cli.publish_verified(
                [first, second], self.root, self.base / "state/library.db", self.job
            )
        self.assertEqual(self.catalogue_rows(), [])
        self.assertEqual(cli.resume_job(self.job)["registered"], 2)

    def test_tampered_resume_journal_is_refused(self):
        cli = self.publisher()
        verified = self.verified_file()
        with (
            patch("cli.os.link", side_effect=OSError("stop")),
            self.assertRaises(OSError),
        ):
            cli.publish_verified(
                [verified], self.root, self.base / "state/library.db", self.job
            )
        journal = json.loads((self.job / "job.json").read_text())
        original = (self.job / "job.json").read_text()
        journal["files"][0]["candidate"] = str(self.source / "song.flac")
        (self.job / "job.json").write_text(json.dumps(journal))
        with self.assertRaisesRegex(ValueError, "job"):
            cli.resume_job(self.job)
        (self.job / "job.json").write_text(original)
        verified.candidate.write_bytes(b"changed")
        with self.assertRaisesRegex(ValueError, "changed"):
            cli.resume_job(self.job)

    def test_catalogue_root_is_bound(self):
        cli = self.publisher()
        verified = self.verified_file()
        db = self.base / "state/library.db"
        cli.publish_verified([verified], self.root, db, self.job)
        with self.assertRaisesRegex(ValueError, "root"):
            cli.catalogue_entries(db, self.base / "other-library")

    def test_repeated_album_batches_share_one_album(self):
        cli = self.publisher()
        first = self.verified_file()
        database = self.base / "state/library.db"
        cli.publish_verified([first], self.root, database, self.job)
        self.job = self.base / ".beets-import.second-batch"
        self.job.mkdir(mode=0o700)
        (self.job / "job.json").write_text(
            json.dumps({"version": 1, "root": str(self.root), "job": str(self.job)})
        )
        second = self.verified_file(
            "second.flac", frequency=880, title="You Oughta Know", track=2
        )
        cli.publish_verified([second], self.root, database, self.job)
        rows = self.catalogue_rows()
        self.assertEqual(len(rows), 2)
        self.assertEqual(rows[0][1], rows[1][1])
        import sqlite3

        with closing(sqlite3.connect(database)) as db:
            self.assertEqual(db.execute("select count(*) from albums").fetchone()[0], 1)

    def test_conflicting_release_in_same_directory_stays_pending(self):
        cli = self.publisher()
        first = self.verified_file()
        database = self.base / "state/library.db"
        cli.publish_verified([first], self.root, database, self.job)
        self.job = self.base / ".beets-import.conflict"
        self.job.mkdir(mode=0o700)
        (self.job / "job.json").write_text(
            json.dumps({"version": 1, "root": str(self.root), "job": str(self.job)})
        )
        second = self.verified_file(
            "other-release.flac",
            frequency=880,
            title="Another Song",
            track=2,
            mb_albumid="6adff1fe-7f2f-4d37-a67c-d67f3c7a5d13",
        )
        with self.assertRaisesRegex(
            ValueError, "release.*directory|directory.*release"
        ):
            cli.publish_verified([second], self.root, database, self.job)
        self.assertFalse((self.root / second.relative_destination).exists())
        self.assertEqual(len(self.catalogue_rows()), 1)

    def test_decoder_error_stays_pending(self):
        metadata = self.metadata_implementation()
        source = self.audio(duration=1)
        source.write_bytes(source.read_bytes()[:-10])
        record = self.implementation().stage_inputs([source], self.job)[0]
        approval = self.approval(record)
        candidate = metadata.prepare_candidate(record, approval, self.job)
        with self.assertRaises((ValueError, subprocess.CalledProcessError)):
            metadata.verify_candidate(record, candidate, approval)

    def test_id3v1_comments_and_genre_survive(self):
        metadata = self.metadata_implementation()
        from mediafile import MediaFile

        for version, comment in [
            (10, b"123456789012345678901234567890"),
            (11, b"Legacy-only comment".ljust(28, b"\x00") + b"\x00\x07"),
        ]:
            for album in [True, False]:
                with self.subTest(version=version, album=album):
                    source = self.audio(
                        f"legacy-{version}-{album}.mp3",
                        {"comment": "Separate V2 comment"},
                        codec="libmp3lame",
                    )
                    media = MediaFile(source)
                    media.comments = "Separate V2 comment"
                    media.save()
                    footer = (
                        b"TAG"
                        + b"Old title".ljust(30, b"\x00")
                        + b"Old artist".ljust(30, b"\x00")
                        + b"Old album".ljust(30, b"\x00")
                        + b"1988"
                        + comment
                        + b"\x13"
                    )
                    source.write_bytes(source.read_bytes() + footer)
                    record = self.implementation().stage_inputs([source], self.job)[0]
                    approval = self.approval(record, as_album=album)
                    candidate = metadata.prepare_candidate(record, approval, self.job)
                    result = candidate.read_bytes()[-128:]
                    self.assertEqual(
                        result[97 : 125 if version == 11 else 127],
                        comment[: 28 if version == 11 else 30],
                    )
                    self.assertEqual(result[-1], 0x13)
                    if version == 11:
                        self.assertEqual(result[-2], 1 if album else 0)
                    metadata.verify_candidate(record, candidate, approval)
                    self.assertEqual(
                        MediaFile(candidate).comments, "Separate V2 comment"
                    )

    def test_approved_edition_survives_in_file_metadata(self):
        metadata = self.metadata_implementation()
        from dataclasses import replace
        from mediafile import MediaFile

        record = self.implementation().stage_inputs([self.audio()], self.job)[0]
        approval = self.approval(record, albumdisambig="2011 remaster")
        approval = replace(approval, edition="Deluxe Edition")
        candidate = metadata.prepare_candidate(record, approval, self.job)
        metadata.verify_candidate(record, candidate, approval)
        disambiguation = MediaFile(candidate).albumdisambig
        self.assertIn("2011 remaster", disambiguation or "")
        self.assertIn("Deluxe Edition", disambiguation or "")

    def test_manual_cli_decline_and_resume(self):
        cli = self.publisher()
        source = self.audio(tags={"title": "00.11"})
        original = source.read_bytes()
        arguments = [
            "--library-root",
            str(self.root),
            "--database",
            str(self.base / "state/library.db"),
            "--state-directory",
            str(self.base / "state"),
        ]
        import contextlib
        import io

        with (
            contextlib.redirect_stdout(io.StringIO()),
            patch("builtins.input", side_effect=["y", "n"]),
        ):
            status = cli.main(
                [
                    *arguments,
                    "--unsorted",
                    "--artist",
                    "John Frusciante",
                    "--title",
                    "Twenty Four Hours",
                    str(source),
                ]
            )
        self.assertEqual(status, 2)
        self.assertFalse(self.root.exists())
        job = json.loads((self.base / "state/latest-job.json").read_text())["job"]
        with (
            contextlib.redirect_stdout(io.StringIO()),
            patch("builtins.input", return_value="y"),
        ):
            status = cli.main([*arguments, "--resume", job])
        self.assertEqual(status, 0)
        self.assertTrue(
            (self.root / "Unsorted/John Frusciante/Twenty Four Hours.flac").is_file()
        )
        self.assertEqual(source.read_bytes(), original)

    def native_match(
        self,
        source,
        name="native",
        year=1995,
        artist_id=None,
        answer="a\n",
        automatic=False,
        fingerprints=False,
    ):
        cli = self.implementation()
        job = self.job / name
        job.mkdir(mode=0o700)
        (job / "job.json").write_text(
            json.dumps({"version": 1, "job": str(job), "root": str(self.root)})
        )
        records = cli.stage_inputs([source], job)
        providers = job / "providers"
        providers.mkdir()
        provider = """
from beets.metadata_plugins import MetadataSourcePlugin
from beets.autotag import AlbumInfo, TrackInfo

class FixtureSourcePlugin(MetadataSourcePlugin):
    data_source = "MusicBrainz"
    def __init__(self):
        super().__init__()
        self.register_listener("import_task_start", self.fingerprint)
    def fingerprint(self, session, task):
        if FINGERPRINTS:
            from beetsplug.chroma import _matches
            for item in task.items:
                _matches[item.path] = (["c5659cc0-b86b-4e2f-95f3-8d55b0d1e672"], ["f4edaaca-02e6-3746-991d-257bb7f9ad14"])
    def track_for_id(self, track_id):
        return TrackInfo(track_id="c5659cc0-b86b-4e2f-95f3-8d55b0d1e672",
                         title="All I Really Want", artist="Alanis Morissette", artists=["Alanis Morissette"],
                         artist_id=ARTIST_ID,
                         length=0.08, index=1, medium=1, medium_index=1, medium_total=1,
                         data_source="MusicBrainz")
    def album_for_id(self, album_id):
        return AlbumInfo(tracks=[self.track_for_id(None)], album="Jagged Little Pill",
                         artist="Alanis Morissette", artists=["Alanis Morissette"], year=RELEASE_YEAR, mediums=1,
                         artist_id=ARTIST_ID,
                         album_id="f4edaaca-02e6-3746-991d-257bb7f9ad14", data_source="MusicBrainz")
    def candidates(self, items, artist, album, va_likely):
        return [self.album_for_id(None)]
    def item_candidates(self, item, artist, title):
        return [self.track_for_id(None)]
"""
        (providers / "fixture_source.py").write_text(
            provider.replace("RELEASE_YEAR", repr(year))
            .replace("ARTIST_ID", repr(artist_id))
            .replace("FINGERPRINTS", repr(fingerprints))
        )
        cfg, env = cli.matcher_configuration(job, automatic)
        cfg["plugins"] = ["fixture_source", "import_audit"]
        cfg["pluginpath"].append(str(providers))
        (job / "config").mkdir()
        (job / "config/config.yaml").write_text(json.dumps(cfg))
        result = subprocess.run(
            [
                sys.executable,
                "-B",
                "-c",
                "from beets.ui import main; main()",
                "import",
                str(records[0].staged.parent),
            ],
            env=env,
            input=answer,
            capture_output=True,
            text=True,
            timeout=20,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("error loading plugin", result.stderr)
        events = [
            json.loads(line)
            for line in (job / "decisions.jsonl").read_text().splitlines()
        ]
        return records, cli.read_approvals(events, records), job

    def test_native_matcher_audit_records_apply_and_as_is(self):
        source = self.audio(
            tags={
                "artist": "Alanis Morissette",
                "album": "Jagged Little Pill",
                "title": "All I Really Want",
                "date": "1995",
            }
        )
        for action, answer, expected in [("apply", "a\n", 1), ("asis", "u\n", 0)]:
            with self.subTest(action=action):
                _, approvals, _ = self.native_match(source, action, answer=answer)
                self.assertEqual(len(approvals), expected)
                if approvals:
                    self.assertEqual(approvals[0].fields["title"], "All I Really Want")
                    self.assertEqual(approvals[0].fields["year"], 1995)
                    self.assertEqual(
                        approvals[0].album_key, "f4edaaca-02e6-3746-991d-257bb7f9ad14"
                    )

    def test_unknown_chosen_release_year_does_not_inherit_source(self):
        metadata = self.metadata_implementation()
        source = self.audio(
            tags={
                "artist": "Alanis Morissette",
                "album": "Jagged Little Pill",
                "title": "All I Really Want",
                "date": "1988",
            }
        )
        _, approvals, _ = self.native_match(source, year=None)
        self.assertEqual(len(approvals), 1)
        with self.assertRaisesRegex(ValueError, "year"):
            metadata.plan_destination(approvals[0], Path("track.flac"))

    def test_chosen_match_does_not_inherit_old_artist_ids(self):
        metadata = self.metadata_implementation()
        source = self.audio(
            tags={
                "artist": "Alanis Morissette",
                "album": "Jagged Little Pill",
                "title": "All I Really Want",
                "date": "1988-07-05",
                "MUSICBRAINZ_ARTISTID": "11111111-1111-4111-8111-111111111111",
                "MUSICBRAINZ_ALBUMARTISTID": "11111111-1111-4111-8111-111111111111",
            }
        )
        records, approvals, job = self.native_match(source)
        candidate = metadata.prepare_candidate(records[0], approvals[0], job)
        metadata.verify_candidate(records[0], candidate, approvals[0])
        from mediafile import MediaFile

        media = MediaFile(candidate)
        self.assertEqual(media.year, 1995)
        self.assertFalse(media.month)
        self.assertFalse(media.day)
        self.assertFalse(media.mb_artistid)
        self.assertFalse(media.mb_albumartistid)

    def test_chosen_artist_ids_survive_alias_writing(self):
        metadata = self.metadata_implementation()
        source = self.audio(
            tags={
                "artist": "Alanis Morissette",
                "album": "Jagged Little Pill",
                "title": "All I Really Want",
                "date": "1995",
            }
        )
        identifier = "11111111-1111-4111-8111-111111111111"
        records, approvals, job = self.native_match(source, artist_id=identifier)
        candidate = metadata.prepare_candidate(records[0], approvals[0], job)
        metadata.verify_candidate(records[0], candidate, approvals[0])
        from mediafile import MediaFile

        media = MediaFile(candidate)
        self.assertEqual(media.mb_artistids, [identifier])
        self.assertEqual(media.mb_albumartistids, [identifier])

    @unittest.skipUnless(
        os.environ.get("BEETS_IMPORT_PACKAGE"),
        "packaged command checked by the Nix fixture",
    )
    def test_packaged_command_imports_manual_identity(self):
        source = self.audio()
        original = source.read_bytes()
        result = subprocess.run(
            [
                os.environ["BEETS_IMPORT_PACKAGE"],
                "--library-root",
                str(self.root),
                "--database",
                str(self.base / "state/library.db"),
                "--state-directory",
                str(self.base / "state"),
                "--unsorted",
                "--artist",
                "John Frusciante",
                "--title",
                "Twenty Four Hours",
                str(source),
            ],
            input="y\ny\n",
            capture_output=True,
            text=True,
            timeout=30,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(
            (self.root / "Unsorted/John Frusciante/Twenty Four Hours.flac").exists()
        )
        self.assertEqual(source.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
