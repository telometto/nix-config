import importlib.util
import gzip
import io
import os
import shutil
import subprocess
import tarfile
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "safe_extract", ROOT / "home/programs/scripts/safe-extract.py"
)
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)
BSDTAR = os.environ.get("BSDTAR", "bsdtar")


class SafeExtractTests(unittest.TestCase):
    def archive(self, root, members):
        path = root / "fixture.tar"
        with tarfile.open(path, "w") as archive:
            for member, data in members:
                member.size = len(data)
                archive.addfile(member, io.BytesIO(data))
        return path

    def test_normal_archive_preserves_caller_files_and_source(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            original = root / "config"
            original.write_text("original")
            path = self.archive(root, [(tarfile.TarInfo("config"), b"incoming")])
            output = helper.extract(path, BSDTAR)
            self.addCleanup(shutil.rmtree, output)
            self.assertEqual((output / "config").read_text(), "incoming")
            self.assertEqual(original.read_text(), "original")
            self.assertTrue(path.exists())
            self.assertEqual(output.stat().st_mode & 0o777, 0o700)

    def test_absolute_traversal_links_and_special_members_fail(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            outside = root / "outside"
            outside.write_text("original")
            for name in (str(outside), "../outside", "a/../../outside"):
                with self.subTest(name=name):
                    with self.assertRaises((ValueError, tarfile.TarError)):
                        helper.extract(
                            self.archive(root, [(tarfile.TarInfo(name), b"bad")]),
                            BSDTAR,
                        )
            link = tarfile.TarInfo("link")
            link.type, link.linkname = tarfile.SYMTYPE, str(outside)
            special = tarfile.TarInfo("device")
            special.type = tarfile.CHRTYPE
            for member in (link, special):
                with self.assertRaises((ValueError, tarfile.TarError)):
                    helper.extract(self.archive(root, [(member, b"")]), BSDTAR)
            self.assertEqual(outside.read_text(), "original")

    def test_zip_sevenzip_and_single_compressed_files_still_work(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "content").write_text("incoming")
            with zipfile.ZipFile(root / "fixture.zip", "w") as archive:
                archive.writestr("content", "incoming")
            subprocess.run(
                [
                    BSDTAR,
                    "-cf",
                    str(root / "fixture.7z"),
                    "--format=7zip",
                    "-C",
                    str(root),
                    "content",
                ],
                check=True,
            )
            with gzip.open(root / "content.gz", "wb") as output:
                output.write(b"incoming")
            for name in ("fixture.zip", "fixture.7z", "content.gz"):
                with self.subTest(name=name):
                    output = helper.extract(root / name, BSDTAR)
                    self.addCleanup(shutil.rmtree, output)
                    self.assertEqual((output / "content").read_text(), "incoming")
                    self.assertTrue((root / name).exists())

    def test_duplicate_members_do_not_overwrite(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = self.archive(
                root,
                [
                    (tarfile.TarInfo("content"), b"first"),
                    (tarfile.TarInfo("content"), b"second"),
                ],
            )
            with self.assertRaises(ValueError):
                helper.extract(path, BSDTAR)


if __name__ == "__main__":
    unittest.main()
