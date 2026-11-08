"""Conservative automatic approval; a native recommendation is not a probability."""

import uuid
import math
import re

from beets.autotag import Recommendation

SINGLETON_POLICY_VERSION = "recording-v1"


def number(value):
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(value)
    )


def placeholder(value):
    return not isinstance(value, str) or re.sub(r"[\W_]+", "", value).casefold() in {
        "",
        "unknown",
        "unknownartist",
        "unknowntrack",
        "variousartists",
        "various",
        "noartist",
        "untitled",
    }


def version_cue(value):
    if isinstance(value, (list, tuple)):
        return any(version_cue(entry) for entry in value)
    if not isinstance(value, str):
        return False
    return bool(
        re.search(
            r"\b(remaster(?:ed|ing)?|remix(?:ed)?|demo|acoustic|instrumental|cover|mono|stereo|alternate|alternative|version|mix|edit)\b"
            r"|(?:^|[\(\[]|\s-\s)\s*(?:live|studio)\b"
            r"|\b(?:live|studio)\s+(?:at|from|in|recording|version|session)\b"
            r"|\b(?:live|studio)\s*(?:[)\]]|$)",
            value,
            re.I,
        )
    )


def recording_choice(task, fingerprints, evidence):
    if task.is_album or len(task.items) != 1:
        return None, "Recording policy requires one loose track"
    item = task.items[0]
    collected = evidence.get(item.path, {})
    response = collected.get("response", {})
    duration = collected.get("duration")
    if (
        collected.get("error")
        or not isinstance(response, dict)
        or response.get("status") != "ok"
    ):
        return None, "Fingerprint lookup failed or is unavailable"
    if (
        not number(duration)
        or duration < 30
        or not number(item.length)
        or abs(item.length - duration) > 2
    ):
        return None, "Fingerprint duration is short, missing or inconsistent"
    results = response.get("results")
    if not isinstance(results, list) or not results:
        return None, "No fingerprint matches"
    if any(
        not isinstance(result, dict)
        or not number(result.get("score"))
        or not 0 <= result["score"] <= 1
        for result in results
    ):
        return None, "Malformed fingerprint scores"
    if max(result["score"] for result in results) < 0.95:
        return None, "Fingerprint support is weak"
    usable = [result for result in results if result["score"] >= 0.5]
    records = []
    for result in usable:
        if (
            not valid_id(result.get("id"))
            or not isinstance(result.get("recordings"), list)
            or not result["recordings"]
        ):
            return None, "An unmapped fingerprint result needs review"
        if any(
            not isinstance(record, dict) or not valid_id(record.get("id"))
            for record in result["recordings"]
        ):
            return None, "Malformed fingerprint recording identities"
        records.extend(result["recordings"])
    identities = {record["id"] for record in records}
    if len(identities) != 1:
        return None, "Conflicting fingerprint recordings or covers need review"
    identity = next(iter(identities))
    if not fingerprints.get(item.path) or set(fingerprints[item.path][0]) != {identity}:
        return None, "Fingerprint candidate cache disagrees with the complete lookup"
    candidates = [
        candidate
        for candidate in (task.candidates or [])
        if getattr(candidate.info, "track_id", None) == identity
        and candidate.info.data_source == "MusicBrainz"
    ]
    if not candidates:
        return None, "Fingerprint recording was not resolved through MusicBrainz"
    signatures = set()
    for candidate in candidates:
        info = candidate.info
        ids = info.artists_ids or ([info.artist_id] if info.artist_id else [])
        if (
            placeholder(info.artist)
            or placeholder(info.title)
            or len(ids) != 1
            or not valid_id(ids[0])
            or info.artist_id != ids[0]
            or info.artists != [info.artist]
        ):
            return None, "Recording artist identity is missing or ambiguous"
        if not number(info.length) or abs(info.length - duration) > 2:
            return None, "MusicBrainz recording duration disagrees"
        if getattr(info, "trackdisambig", None) or version_cue(info.title):
            return None, "Recording version or disambiguation needs review"
        signatures.add((info.artist.casefold(), info.title.casefold(), ids[0]))
    if len(signatures) != 1:
        return None, "Conflicting MusicBrainz recording identities"
    artist_id = candidates[0].info.artist_id
    for record in records:
        artists = record.get("artists")
        if (
            not isinstance(artists, list)
            or len(artists) != 1
            or not isinstance(artists[0], dict)
            or artists[0].get("id") != artist_id
            or placeholder(artists[0].get("name"))
        ):
            return None, "Fingerprint and MusicBrainz artist credits disagree"
        if version_cue(record.get("title")):
            return None, "Fingerprint version information needs review"
        if record.get("duration") is not None and (
            not number(record["duration"]) or abs(record["duration"] - duration) > 2
        ):
            return None, "Fingerprint recording duration disagrees"
    if any(
        version_cue(item.get(field))
        for field in (
            "title",
            "subtitle",
            "album",
            "albumdisambig",
            "disctitle",
            "albumtype",
            "albumtypes",
            "media",
        )
    ):
        return None, "Source version cues require recording review"
    return (
        candidates[0],
        "Unique high-support fingerprint and consistent MusicBrainz recording/artist; release unverified",
    )


def valid_id(value):
    try:
        uuid.UUID(value)
        return True
    except (ValueError, TypeError, AttributeError):
        return False


def automatic_choice(task, fingerprints, recording_evidence=None):
    if not task.is_album:
        return recording_choice(task, fingerprints, recording_evidence or {})
    candidates = list(task.candidates or [])
    if not candidates or task.rec != Recommendation.strong:
        return None, "No strong recommendation"
    candidate = candidates[0]
    info = candidate.info
    if len({match.info.album_id for match in candidates}) != 1:
        return None, "Competing edition candidates need review"
    if info.data_source != "MusicBrainz" or not valid_id(info.album_id):
        return None, "No supported release identity"
    if not info.year or not 1 <= info.year <= 9999 or not info.album or not info.artist:
        return None, "Release identity or year is incomplete"
    pairs = candidate.item_info_pairs
    if (
        candidate.extra_items
        or candidate.extra_tracks
        or len(pairs) != len(info.tracks)
        or len(pairs) != len(task.items)
        or not pairs
    ):
        return None, "Incomplete album mapping needs review"
    indices = [track.index for _, track in pairs]
    if any(not index or index < 1 for index in indices) or len(set(indices)) != len(
        indices
    ):
        return None, "Track order is not established"
    source_release_ids = {item.mb_albumid for item, _ in pairs if item.mb_albumid}
    if source_release_ids and source_release_ids != {info.album_id}:
        return None, "Source edition identifiers disagree"
    known_source_edition = all(item.mb_albumid == info.album_id for item, _ in pairs)
    unique_fingerprint_edition = True
    for item, track in pairs:
        if not track.title or not track.artist or not valid_id(track.track_id):
            return None, "Recording identity is incomplete"
        if not item.length or not track.length or abs(item.length - track.length) > 2:
            return None, "Track duration needs review"
        evidence = fingerprints.get(item.path)
        if not evidence or set(evidence[0]) != {track.track_id}:
            return None, "Missing or ambiguous recording fingerprint"
        unique_fingerprint_edition &= set(evidence[1]) == {info.album_id}
        source_label = item.get("albumdisambig") or ""
        if (
            source_label
            and source_label.casefold() != (info.albumdisambig or "").casefold()
        ):
            return None, "Source edition label needs review"
    if not known_source_edition and not unique_fingerprint_edition:
        return None, "Recording fingerprints do not establish an edition"
    return (
        candidate,
        "Strong complete release supported by recording and edition evidence",
    )
