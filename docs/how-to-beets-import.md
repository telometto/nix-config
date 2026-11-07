# Import music on Blizzard with beets

The Home Manager configuration enables `beets-import` for `zeno` on Blizzard.
It uses MusicBrainz and AcoustID, asks before accepting matches by default, and checks
copied files before publishing them into `/rpool/unenc/media/data/music`.
Deploying the configuration and the first bounded live acceptance run are
separate operational steps; repository checks do not perform either.

## Start with a small selection

Run the command in an interactive SSH session, after the configuration has
been activated through the usual separately authorized process:

```bash
ssh -t zeno@blizzard
beets-import /path/to/a/small/selected/folder
```

You can also pass individual song files. After a bounded acceptance sample,
use bulk mode for larger selected collections. Existing directories remain retained
sources unless you explicitly select one working directory for verified cleanup:

- `/rpool/unenc/media/beets-dl`
- `/home/zeno/Music`
- `/rpool/unenc/media/data/media/music`

The command creates a private `.beets-import.XXXXXXXX` staging directory
beside the final library. Input copies have independent inodes; the original
files are never handed to beets for retagging or moving. A manifest records
their paths, hashes, and metadata. Unsupported inputs remain in place and
appear in `pending-inputs.json` for ordinary jobs or `--queue` for bulk jobs.
Initial supported formats are FLAC (including
FLAC files named `.fla`), MP3, and M4A containing AAC or ALAC. Whole-disc APE
images and cue-sheet splitting need a separate pass.

Mixed folders are grouped by album tags; files without usable album/artist
tags are matched individually. Counts appear before matching. Groups over
100 tracks remain pending: select a smaller, coherent group rather than
accept a directory-sized album. Symlink paths and source/library overlaps
are refused; select the actual independent source directory instead.

## Import a collection incrementally

```bash
beets-import --bulk /path/to/retained/collection
# Optional unattended matching with strict recording and edition checks:
beets-import --auto /path/to/retained/collection
# Stop after ten coherent album/track groups, then resume the same job:
beets-import --bulk --max-units 10 /path/to/retained/collection
```

New plain `beets-import SOURCE...` invocations use the bounded bulk workflow
with interactive matching and publication prompts. `--bulk` is an optional
explicit spelling of that default. `--auto` opts
into bulk automation. Both first inventory source paths and full-file hashes,
then stage one album or loose recording at a time. Each invocation processes
at most 25 groups by default; `--max-units N` changes that limit without
splitting a coherent album. Previously imported albums that only need source
cleanup share this budget; interrupted captures take priority. Already-imported sources
and exact byte copies are skipped before staging only when their corresponding
catalogue output still exists and matches its stored hash. A missing or changed
output goes to review. Similar recordings, re-encodes, and editions are not
exact duplicates.

Recognition uses the source/output hashes and catalogue provenance written by
earlier helper runs, including records without the newer source-path attribute.
The reported 14-track live library is not re-imported merely because another
bulk job is started. The code does not identify those tracks by filename or by
an expected catalogue count. If provenance is missing or invalid, matching
content requires review; this change does not reconstruct missing evidence
from guesses or inspect the live catalogue during development.

Identical inputs within the job share one staged representative. If it still
needs review, its aliases remain linked to that unresolved work; they do not
count as imported. Unsupported files and album groups above 100 tracks enter
review without copying. Progress reports file and byte counts, committed
results, exact duplicates, skipped candidates, and unresolved work.

Automatic **album** acceptance requires a strong native recommendation, a complete album
mapping, a known release year, close track durations, and unique fingerprint
recording evidence for every track. The release identity must also agree with
existing source MusicBrainz release IDs or unique fingerprint release evidence.
Competing editions, incomplete albums, missing evidence,
and publication conflicts go to review. A high displayed score alone is not
enough. Accepted automatic matches undergo the same metadata and audio checks
as interactive imports. There is no unattended as-is fallback.
Loose recordings use the separate recording-only policy below; album rules
are unchanged.

## Review recording and edition identity

Beets' normal terminal importer presents candidate matches. Review artist,
track titles, track count, release year, and edition details. Strong matches
still require approval in the default interactive mode. Use the importer's other-candidate, search/ID,
singleton/regroup, or skip choices when appropriate. A skipped or unchanged
choice does not publish that group.

Fingerprint evidence establishes a recording more readily than an album
edition. The displayed score measures metadata distance; it is not an
identification probability. Preserve studio/live/remix/remaster/deluxe and
compilation distinctions; equivalent regional releases can be equivalent
editions after review.

For approved albums the helper asks for an optional edition label, suggesting
the selected release's disambiguation when available. Enter accepts that
suggestion; `-` omits the path label. Use a meaningful label such as
`Deluxe Edition` or `2011 Remaster` when needed. The selected disambiguation
and any distinct reviewed label are also retained in file metadata.
Unknown release years remain pending, even when old source tags contain a year.
The final path preview follows:

```text
Albums/<album artist>/<edition release year>/<album [edition]>/<track>-<title>.<extension>
Albums/Various Artists/<edition release year>/<album [edition]>/<track>-<title>.<extension>
```

Multi-disc releases use continuous release-wide track numbers and one album
directory. Original audio containers/codecs are retained; `.fla` is normalized
to `.flac` without transcoding.

For a song identified by listening whose album/date is unverified:

```bash
beets-import --unsorted --artist 'John Frusciante' \
  --title 'Twenty Four Hours' /path/to/the/confirmed/song.flac
```

Confirm the displayed artist/title. The output goes to
`Unsorted/John Frusciante/Twenty Four Hours.flac`. Unverified release/date/track
tags are removed from the copy and retained in the job's provenance metadata.
The command does not invent MusicBrainz identifiers.

## Automatically identify loose recordings

Automatic singletons can publish to `Unsorted/<artist>/<title>.<extension>`
without claiming an album, original release, date, edition or mastering.
Policy `recording-v1` uses these conjunctive acceptance criteria:

- A successful Chromaprint/AcoustID lookup has a best fingerprint score of
  at least **0.95**. Every usable result at chroma's native **0.5** floor
  must map to exactly the same single valid MusicBrainz recording ID.
  A competing or unmapped usable result remains queued.
- Fingerprinted duration is finite and at least **30 seconds**, agrees
  with the decoded file within **2 seconds**, and agrees with the resolved
  MusicBrainz recording within **2 seconds**. Available AcoustID recording
  durations must also agree.
- MusicBrainz resolves the fingerprint's recording ID to a non-placeholder
  title and one unambiguous credited artist with a valid artist ID.
  AcoustID's recording artist IDs must agree. Missing/multiple/conflicting
  artists, inconsistent candidates and failed lookups remain queued.
- Explicit version cues in source/provider titles, source subtitles,
  album/disambiguation, disc titles, album types or media descriptions,
  or MusicBrainz recording disambiguation require review. This includes
  live/studio, remix, remaster, demo, acoustic, instrumental, cover and similar
  version indications, including unpunctuated phrases such as `live at Wembley`.
  Source tags can veto automation but cannot establish
  recording identity.

These are conservative policy gates, not identification probabilities. The
native text recommendation/distance is recorded but does not decide recording
identity for artistless files named `00.12_2`. No beets matching threshold is
lowered. The helper excludes the untrusted source-ID search shortcut from the
singleton's temporary search description and preserves the original ID in
evidence; original tags/files are untouched during matching.

The pinned singleton importer has no before-choice hook. Fingerprints and
candidates are collected before its choice event; the helper then selects the
supported recording or skips it before metadata is applied. The former hook
unconditionally skipped singletons and retained no useful evidence. Native
chroma also retains only the best fingerprint cluster, so the helper now
collects the complete response once for singleton policy evaluation while
feeding chroma's usual MusicBrainz candidate resolution.

Every automatic accept/refusal records its policy version, native text
recommendation, candidate IDs/details, lookup scores/recordings/artist credits,
fingerprint duration/hash and original source recording ID. Current queue
evidence is source-specific; superseded attempts remain in the audit journal.
The checked output keeps verified recording/artist IDs and clears unverified
album/date/release/edition tags, including album-artist aliases, disc title,
label, catalogue numbers, barcode, ASIN, country, release type/status, media
and script. Original tags, artwork and exact source bytes
remain in the existing recovery/provenance records. All publication, duplicate,
collision and source-retirement checks still apply.

MusicBrainz recordings can span several releases and masterings. A fingerprint
does **not** prove a particular remaster: no such claim is written. Explicit
or conflicting version evidence remains queued, and unidentified mastering
without a reliable distinguishing cue cannot be resolved by this policy.
See the primary [chroma documentation](https://docs.beets.io/en/stable/plugins/chroma.html),
[AcoustID lookup API](https://acoustid.org/webservice), and
[MusicBrainz recording model](https://musicbrainz.org/doc/Recording).

## Check and publish

The helper changes only approved core identification fields. Composer
credits, lyrics, comments, ratings, ReplayGain, custom tags, and embedded
artwork must survive verification. It compares protected raw tags, artwork,
decoded PCM, compressed audio packets, codec/sample properties, and original
source hashes. MP3 ID3v1 footer comments and genre are checked independently
of the ID3v2 tags; full-length ID3v1.0 comments are retained. Unsupported
legacy trailing-tag layouts stay pending. A tag/decoder failure, including
an error reported with an otherwise successful decoder exit, leaves the
candidate in staging.

Review the final destination preview and answer the publication prompt.
Existing paths and case/Unicode collisions are never replaced. Possible
duplicates show source hashes, artist/title, recording/release IDs, format,
and quality information where available. Each duplicate candidate offers
`k` to keep a reviewed distinct edition, `s` to skip only that candidate,
`l` to skip its whole album, `q` to queue it, or `a` to abort the batch.
Album skip also removes previously selected tracks from that album in the
current publication attempt. Skipping or queuing one allows
unrelated accepted candidates to continue. A conflicting destination cannot
be overridden; revise the edition label or match during review. There is no automatic
merge, quality upgrade, skipped-duplicate deletion, or replacement of a preferred
copy. Source cleanup requires the explicit working-source mode below.

The command publishes verified bytes without replacement and registers them
without another tag write. Later batches extend the same album record when
the edition directory and release identity agree; conflicting identities in
one edition directory stay pending. Its result reports file and byte counts, pending
inputs, and the job path. Exit status `0` means the selected supported results
were published with no pending entries; `2` means work remains, a duplicate was
deferred, a cleanup failed, or publication
was declined; `1` means an error; `130` means interruption.

## Resume and inspect

State lives under `${XDG_STATE_HOME:-$HOME/.local/state}/beets`; the latest job
pointer is `latest-job.json`. Helper caches use
`${XDG_CACHE_HOME:-$HOME/.cache}/codex/beets`. Job copies and evidence are kept
for review; removing them is a separate cleanup decision.

```bash
beets-import --resume /path/printed/by/the/command/.beets-import.XXXXXXXX
# Read persistent per-source outcomes and file/byte totals:
beets-import --status /path/printed/by/the/command/.beets-import.XXXXXXXX
# Inspect unresolved bulk sources and reasons without modifying the job:
beets-import --queue /path/printed/by/the/command/.beets-import.XXXXXXXX
# Review unresolved units interactively, even for an automatic job:
beets-import --review /path/printed/by/the/command/.beets-import.XXXXXXXX
# Retry failed or unidentified sources; interactive by default:
beets-import --retry /path/printed/by/the/command/.beets-import.XXXXXXXX
# Limit retry to an inventoried source (repeat --source for more):
beets-import --retry /path/printed/by/the/command/.beets-import.XXXXXXXX \
  --source /path/to/retained/collection/song.flac
# Give queued loose tracks one automatic attempt under the current policy:
beets-import --retry /path/printed/by/the/command/.beets-import.XXXXXXXX \
  --only-singletons --auto --max-units 5
```

Bulk resume retains its original interactive/automatic mode. Add `--auto` to
opt an interrupted interactive job into automation. It reuses completed
inventory, independently verified staging copies, native match decisions, and
prepared candidates. It reconciles committed outputs and recovers interrupted
publication before continuing; interrupted work never counts as imported.
Completed sources and deliberate candidate skips are not matched again. Queued
duplicates stay queued until `--review`; failed/unidentified work can use
`--retry` (add `--auto` to opt that retry into the automatic policy).
Repeated resumes do not repeatedly
present the same uncertainties.
For publication conflicts, `--queue` gives the reason; `--review` displays
the detailed duplicate comparisons and destination preview.

`--only-singletons` scopes existing-job retry/resume/review to loose-track
units, including cleanup work. Automatic scoped retry selects a bounded batch
before resetting its checkpoints. Repeat the same command to advance the
next eligible queued singletons. A durable `REVIEW` under the current policy
is not automatically matched again; the command reports eligible/selected
counts, which reach zero after the queued set has had its policy attempt.
Changed or missing sources do not consume the retry capacity of later eligible
singletons; they stay recorded for review.
Generic retry and interactive review remain explicit ways to reassess work.
Use `--refresh-evidence` with scoped automatic retry when provider data may
have changed or after a transient lookup failure. That flag deliberately
permits a new attempt at current-policy uncertainty.

After interruption, use scoped `--resume`, which retains completed matching
decisions and continues pending singleton work. A durable current-policy
`REVIEW` counts as a completed attempt even if interruption preceded the
following native `SKIP` record. An exit status of `2` remains
normal while genuine uncertainty or unrelated albums remain queued.

Review reuses a checked proposal or lets you match again. Reusing an album
proposal allows an edition-label correction before another destination preview;
changed candidates are verified again. Unsupported inputs and oversized groups
remain listed with a reason; select a supported, smaller coherent group in a
new job after addressing that reason. Inventory is a snapshot: new files or
changed source bytes require a new bulk job, whose pre-staging checks still
recognize already committed content. Changed or unavailable snapshot sources
stay in the review queue.

The SQLite inventory persists these public outcomes. `--status` reconciles
durable catalogue registration and cleanup completion when an interruption
preceded the parent checkpoint. It reports the last checked state without
writing to the inventory/catalogue or rehashing user files;
resume revalidates the relevant sources and canonical outputs.

| Status | Meaning |
| --- | --- |
| `pending` | Discovered or ready for a later bounded batch |
| `imported` | Content has a verified canonical output; the source is retained, including exact-copy aliases |
| `moved` | The inventoried working source was retired; an original-byte recovery copy remains |
| `duplicate_awaiting_review` | Possible duplicate or explicit candidate/album skip; source retained |
| `unidentified` | Recording or edition evidence is incomplete; source retained |
| `failed` | Read, preservation, publication, source-change or cleanup failure; see the reason and cleanup phase |

File/byte totals count source paths, so two exact copies count as two source
files with imported content. `moved` counts only originals actually retired,
never their retained aliases. A failed cleanup can coexist with successful
publication; the report exposes its cleanup phase, reason, capture path and
recovery path. Separate `cleanup_pending_files` and `cleanup_pending_bytes`
totals distinguish imported content whose authorized cleanup is still pending.
Older bulk jobs gain persistent outcome fields when resumed;
status inspection itself does not upgrade a job.

## Retire originals from one working source

Ordinary imports keep originals. To retire successfully imported files from
one explicitly selected, quiescent working directory:

```bash
beets-import --bulk --move-after-verification /path/to/working-copy
# Optional automatic matching; uncertain work remains retained:
beets-import --auto --move-after-verification /path/to/working-copy
```

That directory supplies the source selection when no positional paths are
given. Any positional file/subdirectory selections must lie inside it. The
job records this authorization; `--resume JOB` and `--retry JOB` continue its
cleanup without requiring the flag again. A copy job cannot be converted to
move mode on resume. Other backup locations and exact-copy aliases are never
retired automatically, and skipped candidates remain in place.

Before cleanup, the helper requires a valid catalogue registration, exact
source-path/hash provenance, the original preservation/approval journal, and
an independent recovery copy. It rechecks the published file's hash, audio,
protected metadata/artwork, approved identity and layout. It then journals
an atomic capture into a private directory beside the source and verifies
the captured original again before unlinking it. Cleanup intent, capture,
removal and completion are durable checkpoints. If interrupted after unlink,
recovery still requires the canonical output and recovery bytes to validate.
It never unlinks a replacement that has appeared at the original pathname.

Already-imported originals can be retired without rematching when this full
provenance survives. A recovery copy may be created for cleanup even though
matching staging was skipped. Older entries with hashes but no source-path
provenance still avoid re-imports, but remain retained exact-copy matches;
they do not authorize source deletion.

Manual `--unsorted` identification remains a single-file operation with its
existing approval/recovery flow. Old ordinary jobs still support `--resume`;
the new per-source status/retry commands apply to bulk jobs.

Cleanup errors remain `failed` and are retried by resume or targeted retry.
If capture already happened, inspect `--status JOB`: the file may be retained
at the reported capture path instead of its original pathname. Keep the job
and recovery copies and resume it before starting another job on that working
directory. A changed source requires a new inventory; do not force cleanup.
The helper reserves `.beets-import-retire-*` directories for interrupted
captures and excludes them from recursive discovery.

Recovery and staging copies are retained initially, so disk usage grows with
completed work. Their later removal is a separate decision. The helper locks
its own jobs but cannot coordinate unrelated editors or library writers;
keep the selected working source and destination quiescent during cleanup.

## Adopt this policy for the existing Blizzard job

Read-only inspection confirmed job `.beets-import.IDDg2nXx` has 334 sources:
14 imported, 268 pending and 52 unidentified, including the 23-track album
and 29 old-policy singletons. No live fingerprint lookup, matching, publication,
retirement or recovery/catalogue mutation is part of implementation/testing.

**This existing job retains move-after-verification authorization for
`/rpool/unenc/media/beets-dl/1970/01/01/flac`.** The future retry/resume commands
below can publish verified results and retire their unchanged working originals,
retaining recovery copies. They leave the album review alone. These commands
are instructions for the operator; they were not run against real media.

From the updated local checkout, build only the helper from the public locked
nixpkgs input. This includes uncommitted/new helper files and needs no host
evaluation or NixOS/Home Manager activation:

```bash
helper_package=$(nix build --impure --no-link --print-out-paths --expr '
  let
    lock = builtins.fromJSON (builtins.readFile ./flake.lock);
    pkgs = import (builtins.fetchTree lock.nodes.nixpkgs.locked) {
      system = "x86_64-linux";
    };
  in import ./lib/beets-import-package.nix { inherit pkgs; }
')
nix copy --to ssh-ng://blizzard "$helper_package"

job=/rpool/unenc/media/data/.beets-import.IDDg2nXx
helper_command="$helper_package/bin/beets-import --library-root /rpool/unenc/media/data/music --database /home/zeno/.local/share/beets/library.db --state-directory /home/zeno/.local/state/beets"

# Read-only status, using the new helper without switching configuration:
ssh blizzard "$helper_command --status $job"

# Retry up to five queued singletons under recording-v1:
ssh -t blizzard "$helper_command --retry $job --only-singletons --auto --max-units 5"

# Repeat the retry command to advance the old-policy queue. To continue
# interrupted/pending singletons while leaving queued uncertainty alone:
ssh -t blizzard "$helper_command --resume $job --only-singletons --auto --max-units 5"
```

An intentionally renewed evidence lookup uses:

```bash
ssh -t blizzard "$helper_command --retry $job --only-singletons --auto --refresh-evidence --max-units 5"
```

No new inventory, old-job deletion, history reset or ordinary `beet import`
is needed. The 14 imported sources remain recognized; the 23-track album is
not rematched by singleton-scoped commands. Newly published files still face
canonical duplicate/path checks, so an existing track is never replaced.

Resume checks the configured root, journal paths, source/candidate/output
hashes, and catalogue provenance. After publication has begun, it can recover
verified files whose catalogue registration was interrupted. An existing
valid registration is recognized once. Before publication has begun, the
preview and confirmation still apply. For ordinary jobs, if matching was interrupted, completed
approvals are available; unmatched files remain pending for another selected
run. Changed files or unexpected existing paths require review rather than
automatic repair/deletion.

The fresh catalogue is `${XDG_DATA_HOME:-$HOME/.local/share}/beets/library.db`.
The original `~/.config/beets/library.db` remains retained; the helper does
not migrate or open it. Initialize the new catalogue through the helper
before ordinary catalogue commands. A `library.db.root.json` sidecar binds
it to its stable library root. An existing unbound database is refused and
must be reviewed; changing `directory` cannot safely rebase stored paths.

After a successful import, ordinary read-only queries are useful:

```bash
beet list -a
beet list -f '$artist - $title: $path'
beet stats
```

Use `beets-import` for imports. Raw mutating `beet import`, `modify`, `write`,
`move`, or duplicate-removal commands bypass its checks. Do not run them
concurrently with a guided import. One guided import can run at a time; a
second invocation reports the active job.

## Acceptance boundaries

The automated `beets-import` flake check uses public locked Home Manager and
nixpkgs inputs, generated media, and a local metadata-source fixture. It
checks preservation, real importer decision events, automatic acceptance and
refusal, pre-staging duplicate skips, review replay, conflict handling,
interruption recovery, source retirement and persistent status, and the
installed commands without contacting metadata
providers or opening user files. Its standalone invocation is documented in
`tests/beets-import.nix` for environments without private `nix-secrets` access.

The successful earlier pilot remains under
`/rpool/unenc/media/beets-pilot.uh5Q5jI1`; it is not automatically promoted.
Before expanding the automatic recording policy, repeat a bounded acceptance
sample. Similar-recording duplicate resolution, recovery-copy retirement,
whole-disc recovery, and playback integration remain later work.

See the [design](superpowers/specs/2026-11-05-blizzard-beets-design.md) and
[implementation plan](superpowers/plans/2026-11-05-blizzard-beets.md) for the
agreed policies and pilot limits.
The [bulk extension design](superpowers/specs/2026-11-05-beets-bulk-design.md)
and [plan](superpowers/plans/2026-11-05-beets-bulk.md) describe resumability
and the optional automatic policy.
The [working-source design](superpowers/specs/2026-11-06-beets-working-source-design.md)
and [plan](superpowers/plans/2026-11-06-beets-working-source.md) cover status,
bounded invocations, retry and optional source retirement.
The [recording-only design](superpowers/specs/2026-11-06-beets-singletons-design.md)
and [plan](superpowers/plans/2026-11-06-beets-singletons.md) describe automatic
singleton evidence, release-free output and versioned scoped retry.
