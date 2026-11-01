import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { join } from "node:path";
import test from "node:test";
import { pathToFileURL } from "node:url";

const packageDir = process.argv[2];
const require = createRequire(join(packageDir, "package.json"));
const bencode = require("bencode");
const { Metafile } = await import(pathToFileURL(join(packageDir, "dist/parseTorrent.js")));
const name = "Example.Movie.2026.1080p.WEB-DL-GROUP";
const decode = (info) => Metafile.decode(Buffer.from(bencode.encode({
  info: {
    name: Buffer.from(name),
    "piece length": 16384,
    pieces: Buffer.alloc(20, 7),
    private: 1,
    ...info,
  },
})));

// Test the effective values after bencode decoding, including UTF-8 overrides.
for (const field of ["name", "name.utf-8"]) {
  for (const unsafe of ["../outside", "nested/../../outside", "..\\outside", "/outside", "C:\\outside"]) {
    test(`rejects unsafe ${field}: ${unsafe}`, () => {
      assert.throws(() => decode({ length: 32, [field]: Buffer.from(unsafe) }), /path outside/);
    });
  }
}

for (const field of ["path", "path.utf-8"]) {
  for (const unsafe of [["..", "outside.mkv"], ["nested/../../outside.mkv"], ["nested\\..\\..\\outside.mkv"]]) {
    test(`rejects unsafe ${field}: ${JSON.stringify(unsafe)}`, () => {
      const file = {
        length: 32,
        path: [Buffer.from("ordinary.mkv")],
        [field]: unsafe.map((part) => Buffer.from(part)),
      };
      assert.throws(() => decode({ files: [file] }), /path outside/);
    });
  }
}

test("accepts ordinary single-file metadata and the selected UTF-8 name", () => {
  const metafile = decode({ length: 32, "name.utf-8": Buffer.from("renamed.mkv") });
  assert.equal(metafile.name, "renamed.mkv");
  assert.equal(metafile.files[0].path, "renamed.mkv");
  assert.equal(metafile.length, 32);
});

test("preserves safe nested paths, empty components, and UTF-8 path precedence", () => {
  const metafile = decode({ files: [{
    length: 32,
    path: [Buffer.from("fallback.mkv")],
    "path.utf-8": [Buffer.from("disc/subdir"), Buffer.from(""), Buffer.from("renamed.mkv")],
  }] });
  assert.equal(metafile.files[0].path, `${name}/disc/subdir/_/renamed.mkv`);
  assert.equal(metafile.length, 32);
});
