"""Collect one complete AcoustID lookup before singleton candidate resolution."""

import hashlib
import math

import acoustid
from beets import util
from beetsplug import chroma


def collect(path):
    for cache in (chroma._matches, chroma._fingerprints, chroma._acoustids):
        cache.pop(path, None)
    evidence = {}
    try:
        duration, fingerprint = acoustid.fingerprint_file(util.syspath(path))
        fingerprint = (
            fingerprint.decode() if isinstance(fingerprint, bytes) else fingerprint
        )
        evidence.update(
            duration=duration,
            fingerprint_sha256=hashlib.sha256(fingerprint.encode()).hexdigest(),
        )
        chroma._fingerprints[path] = fingerprint
        response = acoustid.lookup(
            chroma.API_KEY,
            fingerprint,
            duration,
            meta="recordings releases",
            timeout=10,
        )
        evidence["response"] = response
        results = (
            response.get("results", [])
            if isinstance(response, dict) and response.get("status") == "ok"
            else []
        )
        usable = [
            result
            for result in results
            if isinstance(result, dict)
            and isinstance(result.get("score"), (int, float))
            and math.isfinite(result["score"])
            and result["score"] >= chroma.SCORE_THRESH
        ]
        if usable:
            best = max(usable, key=lambda result: result["score"])
            recordings = best.get("recordings", [])
            if isinstance(recordings, list) and all(
                isinstance(recording, dict) for recording in recordings
            ):
                chroma._matches[path] = (
                    [
                        recording["id"]
                        for recording in recordings
                        if isinstance(recording.get("id"), str)
                    ],
                    [
                        release["id"]
                        for recording in recordings
                        for release in recording.get("releases", [])
                        if isinstance(release, dict)
                        and isinstance(release.get("id"), str)
                    ],
                )
                if isinstance(best.get("id"), str):
                    chroma._acoustids[path] = best["id"]
    except (
        acoustid.AcoustidError,
        OSError,
        ValueError,
        TypeError,
        UnicodeError,
    ) as exc:
        evidence["error"] = str(exc)
    return evidence
