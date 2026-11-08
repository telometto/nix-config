"""Media records and preservation checks for guided beets imports."""

from dataclasses import dataclass
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import uuid

from mediafile import MediaFile, UnreadableFileError
from mutagen.id3 import Frame, ID3TimeStamp, ID3, ID3NoHeaderError


FFMPEG = "ffmpeg"
FFPROBE = "ffprobe"
IDENTITY = {"artist", "artists", "title"}
MB_FIELDS = {
    "mb_trackid",
    "mb_albumid",
    "mb_releasegroupid",
    "mb_releasetrackid",
    "mb_artistid",
    "mb_artistids",
    "mb_albumartistid",
    "mb_albumartistids",
}
RELEASE = {
    "album",
    "albumartist",
    "albumartists",
    "albumdisambig",
    "date",
    "year",
    "month",
    "day",
    "track",
    "tracktotal",
    "disc",
    "disctotal",
    "comp",
}
ORIGINAL_DATE = {"original_date", "original_year", "original_month", "original_day"}
# These describe a release rather than the verified recording. Keep the album
# write path unchanged; a recording-only output must not assert source editions.
SINGLETON_RELEASE = RELEASE | {
    "albumartist_credit",
    "albumartist_sort",
    "albumartists_credit",
    "albumartists_sort",
    "albumstatus",
    "albumtype",
    "albumtypes",
    "asin",
    "barcode",
    "catalognum",
    "catalognums",
    "country",
    "disctitle",
    "label",
    "media",
    "script",
}


@dataclass(frozen=True)
class SourceRecord:
    source: Path
    staged: Path
    sha256: str
    metadata: dict


@dataclass(frozen=True)
class Approval:
    source_sha256: str
    fields: dict
    album_key: str | None
    edition: str = ""


@dataclass(frozen=True)
class VerifiedFile:
    source_sha256: str
    candidate: Path
    relative_destination: Path
    fields: dict
    album_key: str | None
    verification: dict


def sha256(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def source_metadata(path: Path) -> dict:
    media = MediaFile(path)
    if media.type not in {"flac", "mp3", "aac", "alac"}:
        raise ValueError(f"Unsupported format; retained pending support: {path}")
    fields = {
        key: getattr(media, key)
        for key in [
            "artist",
            "albumartist",
            "album",
            "title",
            "year",
            "comp",
            "mb_albumid",
        ]
    }
    if media.type == "mp3" and media.mgfile.tags.version[1] not in {3, 4}:
        raise ValueError(
            f"Unsupported legacy metadata version; retained pending support: {path}"
        )
    return {"fields": fields, "format": media.type, "raw": raw_snapshot(media)}


def normalise_tag(value):
    """Represent known raw values without losing lists, binary data, or frames."""
    if value is None or isinstance(value, (str, bool, int)):
        return value
    if isinstance(value, float) and math.isfinite(value):
        return value
    if isinstance(value, bytes):
        result = {"sha256": hashlib.sha256(value).hexdigest(), "bytes": len(value)}
        if hasattr(value, "imageformat"):
            result["imageformat"] = int(value.imageformat)
        if hasattr(value, "dataformat"):
            result["dataformat"] = int(value.dataformat)
        return result
    if isinstance(value, ID3TimeStamp):
        return str(value)
    if isinstance(value, Frame):
        return {"frame": type(value).__name__, "values": normalise_tag(vars(value))}
    if isinstance(value, dict):
        return {str(k): normalise_tag(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [normalise_tag(v) for v in value]
    raise ValueError(f"Unsupported metadata value type: {type(value).__name__}")


def raw_snapshot(media: MediaFile) -> dict:
    tags = (
        id3v2_tags(Path(os.fsdecode(media.filename)))
        if media.type == "mp3"
        else media.mgfile.tags
    )
    result = {
        "tags": {key: normalise_tag(value) for key, value in (tags or {}).items()}
    }
    result["unknown_frames"] = normalise_tag(getattr(tags, "unknown_frames", []))
    result["pictures"] = [
        normalise_tag(vars(picture))
        for picture in getattr(media.mgfile, "pictures", [])
    ]
    if media.type == "mp3":
        footer = id3v1_footer(Path(os.fsdecode(media.filename)))
        result["id3v1"] = footer.hex() if footer else None
    return result


def id3v2_tags(path: Path):
    try:
        return ID3(path, load_v1=False)
    except ID3NoHeaderError:
        return ID3()


def read_media(path: Path, id3v23=False) -> MediaFile:
    media = MediaFile(path, id3v23=id3v23)
    if media.type == "mp3":
        # Mutagen's merged v1 view can invent a track from v1.0 comment bytes.
        # Read/write canonical fields from v2 and inspect v1 independently.
        media.mgfile.tags = id3v2_tags(path)
    return media


def id3v1_footer(path: Path) -> bytes | None:
    with path.open("rb") as stream:
        stream.seek(max(0, path.stat().st_size - 355))
        tail = stream.read()
    footer = tail[-128:] if len(tail) >= 128 and tail[-128:-125] == b"TAG" else None
    preceding = tail[:-128] if footer else tail
    if (
        preceding.startswith(b"TAG+")
        or preceding.endswith((b"LYRICSEND", b"LYRICS200"))
        or preceding[-32:-24] == b"APETAGEX"
        or preceding[-10:-7] == b"3DI"
    ):
        raise ValueError("Unsupported legacy trailing metadata; retain pending support")
    return footer


def protected_footer(footer: bytes | None):
    if footer is None:
        return None
    v11 = footer[125] == 0
    return {
        "layout": 11 if v11 else 10,
        "comment": footer[97 : 125 if v11 else 127].hex(),
        "genre": footer[127],
    }


def preserve_id3v1(source: Path, candidate: Path, tags: dict):
    before, after = id3v1_footer(source), id3v1_footer(candidate)
    if before is None:
        if after is not None:
            raise ValueError("Unexpected new legacy metadata footer")
        return
    if after is None:
        raise ValueError("Legacy metadata footer disappeared")
    restored = bytearray(after)
    if before[125] == 0:
        restored[97:125] = before[97:125]
        restored[125] = 0
        track = tags.get("track") or 0
        restored[126] = track if 0 <= track <= 255 else 0
    else:
        # A v1.0 comment owns all 30 bytes; its track number lives in v2.
        restored[97:127] = before[97:127]
    restored[127] = before[127]
    with candidate.open("r+b") as stream:
        stream.seek(-128, os.SEEK_END)
        stream.write(restored)


def write_fields(approval: Approval) -> dict:
    fields = approval.fields
    if not all(
        isinstance(fields.get(key), str) and fields[key].strip()
        for key in ["artist", "title"]
    ):
        raise ValueError("Recording artist and title must be explicitly identified")
    result = {key: fields[key] for key in ["artist", "title"]}
    result["artists"] = fields.get("artists") or [fields["artist"]]
    if not approval.album_key:
        result.update(
            {
                key: None
                for key in (SINGLETON_RELEASE | ORIGINAL_DATE | MB_FIELDS)
                & set(MediaFile.fields())
            }
        )
        # A recording can be verified independently of every release. Only
        # explicit approved recording/artist IDs survive; source IDs are cleared.
        for key in ("mb_trackid", "mb_artistid", "mb_artistids"):
            value = fields.get(key)
            if value:
                for identifier in value if isinstance(value, list) else [value]:
                    try:
                        uuid.UUID(identifier)
                    except (ValueError, TypeError, AttributeError) as exc:
                        raise ValueError(
                            f"Invalid verified MusicBrainz identifier: {key}"
                        ) from exc
                result[key] = value
        artists = fields.get("mb_artistids") or (
            [fields["mb_artistid"]] if fields.get("mb_artistid") else None
        )
        if (
            fields.get("mb_artistid")
            and artists
            and fields["mb_artistid"] != artists[0]
        ):
            raise ValueError("Verified artist identifiers disagree")
        result.pop("mb_artistid", None)
        result["mb_artistids"] = artists
        return result
    if not fields.get("album") or not fields.get("albumartist"):
        raise ValueError("Album title and album artist must be identified")
    year = fields.get("year", 0)
    if not isinstance(year, int) or not 1 <= year <= 9999:
        raise ValueError("Selected release year is unknown")
    result.update(
        {key: None for key in (RELEASE | MB_FIELDS) & set(MediaFile.fields())}
    )
    result.update(
        {
            "album": fields["album"],
            "albumartist": fields["albumartist"],
            "albumartists": fields.get("albumartists") or [fields["albumartist"]],
            "year": year,
        }
    )
    for key in ["month", "day", "track", "tracktotal", "disc", "disctotal"]:
        value = fields.get(key)
        if isinstance(value, int) and value > 0:
            result[key] = value
    if "comp" in fields:
        result["comp"] = bool(fields["comp"])
    for key in MB_FIELDS & set(MediaFile.fields()):
        value = fields.get(key)
        if value:
            for identifier in value if isinstance(value, list) else [value]:
                try:
                    uuid.UUID(identifier)
                except (ValueError, TypeError, AttributeError) as exc:
                    raise ValueError(
                        f"Invalid verified MusicBrainz identifier: {key}"
                    ) from exc
            result[key] = value
    # Singular/list ID fields address the same raw tag. Write one alias only.
    for singular, plural in [
        ("mb_artistid", "mb_artistids"),
        ("mb_albumartistid", "mb_albumartistids"),
    ]:
        value = fields.get(plural) or (
            [fields[singular]] if fields.get(singular) else None
        )
        result.pop(singular, None)
        result[plural] = value
    disambiguation = fields.get("albumdisambig") or ""
    labels = [disambiguation] if disambiguation else []
    if approval.edition and approval.edition.casefold() != disambiguation.casefold():
        labels.append(approval.edition)
    result["albumdisambig"] = "; ".join(labels) or None
    return result


def allowed_raw_keys(media: MediaFile, fields: dict) -> set[str]:
    """Use the pinned MediaFile descriptors so aliases are checked too."""
    keys = set()
    for field in fields:
        descriptor = vars(MediaFile)[field]
        descriptor = getattr(descriptor, "date_field", descriptor)
        descriptors = [descriptor]
        if hasattr(descriptor, "_year_field"):
            descriptors.append(descriptor._year_field)
        for item in descriptors:
            for style in item.styles(media.mgfile):
                key = style.key
                if hasattr(style, "description"):
                    key += ":" + style.description
                keys.add(key.casefold())
    return keys


def prepare_candidate(source: SourceRecord, approval: Approval, job: Path) -> Path:
    if (
        source.sha256 != approval.source_sha256
        or sha256(source.staged) != source.sha256
    ):
        raise ValueError(
            "Staged source changed or approval does not belong to this source"
        )
    tags = write_fields(approval)
    media = MediaFile(source.staged)
    extension = {"flac": ".flac", "mp3": ".mp3", "aac": ".m4a", "alac": ".m4a"}[
        media.type
    ]
    key = hashlib.sha256(json.dumps(tags, sort_keys=True).encode()).hexdigest()[:20]
    candidate = job / "candidates" / source.sha256 / (key + extension)
    candidate.parent.mkdir(parents=True, exist_ok=True)
    if candidate.is_symlink():
        raise ValueError("Candidate must be an independent job-owned file")
    if candidate.exists():
        try:
            verify_candidate(source, candidate, approval)
            return candidate
        except (ValueError, UnreadableFileError, subprocess.CalledProcessError):
            # Older helpers could leave a partial copy or unfinished tag write.
            # Never rebuild a candidate already linked into the library.
            if candidate.stat().st_nlink != 1:
                raise
    temporary = candidate.with_name(".candidate-" + uuid.uuid4().hex + extension)
    # Match ordinary file creation permissions, including the caller's umask.
    fd = os.open(temporary, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o666)
    try:
        with os.fdopen(fd, "wb") as dst, source.staged.open("rb") as src:
            shutil.copyfileobj(src, dst)
        id3v23 = media.type == "mp3" and media.mgfile.tags.version[1] == 3
        output = read_media(temporary, id3v23=id3v23)
        output.update(tags)
        output.save()
        if media.type == "mp3":
            preserve_id3v1(source.staged, temporary, tags)
        verify_candidate(source, temporary, approval)
        with temporary.open("rb") as stream:
            os.fsync(stream.fileno())
        os.replace(temporary, candidate)
        directory = os.open(candidate.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        temporary.unlink(missing_ok=True)
    return candidate


def audio_signature(path: Path) -> dict:
    probe = subprocess.run(
        [
            FFPROBE,
            "-v",
            "error",
            "-select_streams",
            "a",
            "-show_entries",
            "stream=codec_name,sample_fmt,sample_rate,channels,channel_layout,bits_per_sample,bits_per_raw_sample",
            "-of",
            "json",
            str(path),
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    streams = json.loads(probe.stdout)["streams"]
    if probe.stderr.strip():
        raise ValueError("Audio probe error: " + probe.stderr.strip())
    if len(streams) != 1:
        raise ValueError(
            "Expected one ordinary audio stream; retain input pending review"
        )
    result = {"stream": streams[0]}
    for name, codec in [("pcm_sha256", "pcm_s32le"), ("packet_sha256", "copy")]:
        hashed = subprocess.run(
            [
                FFMPEG,
                "-v",
                "error",
                "-nostdin",
                "-xerror",
                "-err_detect",
                "explode",
                "-i",
                str(path),
                "-map",
                "0:a:0",
                "-c:a",
                codec,
                "-f",
                "hash",
                "-hash",
                "sha256",
                "-",
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        if hashed.stderr.strip():
            raise ValueError("Audio decoder error: " + hashed.stderr.strip())
        label, digest = hashed.stdout.strip().split("=", 1)
        if label != "SHA256" or len(digest) != 64:
            raise ValueError("Unrecognized audio verification result")
        result[name] = digest
    return result


def verify_candidate(source: SourceRecord, candidate: Path, approval: Approval) -> dict:
    if sha256(source.staged) != source.sha256 or sha256(source.source) != source.sha256:
        raise ValueError("Source changed; publication blocked")
    before, after = read_media(source.staged), read_media(candidate)
    tags = write_fields(approval)
    allowed = allowed_raw_keys(before, tags)
    original = source.metadata["raw"]
    result = raw_snapshot(after)
    if before.type == "mp3":
        old_footer = bytes.fromhex(original["id3v1"]) if original.get("id3v1") else None
        new_footer = bytes.fromhex(result["id3v1"]) if result.get("id3v1") else None
        if protected_footer(old_footer) != protected_footer(new_footer):
            raise ValueError("Protected legacy metadata footer changed")
    protected_before = {
        k: v for k, v in original["tags"].items() if k.casefold() not in allowed
    }
    protected_after = {
        k: v for k, v in result["tags"].items() if k.casefold() not in allowed
    }
    if (
        protected_before != protected_after
        or original["pictures"] != result["pictures"]
        or original["unknown_frames"] != result["unknown_frames"]
    ):
        raise ValueError("Protected metadata or artwork changed; publication blocked")
    deleted_keys = allowed_raw_keys(
        before, {k: v for k, v in tags.items() if v is None}
    )
    retained_keys = allowed_raw_keys(
        before, {k: v for k, v in tags.items() if v is not None}
    )
    if any(key.casefold() in deleted_keys - retained_keys for key in result["tags"]):
        raise ValueError("Unverified or zero-placeholder metadata remains")
    for key, expected in tags.items():
        if key == "date" and expected is None and approval.album_key:
            continue  # The following date components specify the selected partial date.
        value = getattr(after, key)
        if expected is None:
            if value not in (None, "", [], 0, False):
                raise ValueError(f"Unverified metadata remains: {key}")
        elif value != expected:
            raise ValueError(f"Approved metadata was not written correctly: {key}")
    a, b = audio_signature(source.staged), audio_signature(candidate)
    if a != b:
        raise ValueError("Audio packets, decoded PCM, or codec properties changed")
    return {
        **b,
        "sha256": sha256(candidate),
        "source_sha256": source.sha256,
        "protected_metadata": True,
        "format": after.type,
    }


def component(value: str) -> str:
    from beets.util import sanitize_path, truncate_str

    if not isinstance(value, str) or not value.strip():
        raise ValueError("Missing path identity component")
    result = sanitize_path(value.replace("/", "_").replace("\\", "_"))
    result = truncate_str(result, 200)
    if result in {"", ".", ".."}:
        raise ValueError("Invalid destination component")
    return result


def plan_destination(approval: Approval, candidate: Path) -> Path:
    fields = write_fields(approval)
    title = component(fields["title"])
    if not approval.album_key:
        return Path("Unsorted", component(fields["artist"]), title + candidate.suffix)
    track = fields.get("track")
    if not track:
        raise ValueError("Verified release track index is unknown")
    artist = "Various Artists" if fields.get("comp") else fields["albumartist"]
    album = fields["album"] + (f" [{approval.edition}]" if approval.edition else "")
    return Path(
        "Albums",
        component(artist),
        str(fields["year"]),
        component(album),
        f"{track:02d}-{title}{candidate.suffix}",
    )
