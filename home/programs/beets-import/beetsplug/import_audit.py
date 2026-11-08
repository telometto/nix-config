"""Record actual importer decisions for the job that loaded this plugin."""

import json
import os
from pathlib import Path

from beets.plugins import BeetsPlugin


class ImportAuditPlugin(BeetsPlugin):
    def __init__(self):
        super().__init__()
        self.config.add(
            {"log": "", "automatic": False, "collect_recording_evidence": False}
        )
        self.recording_evidence = {}
        self.register_listener("import_task_start", self.started)
        self.register_listener("import_task_apply", self.applied)
        self.register_listener("import_task_choice", self.choice)
        self.register_listener("import_task_before_choice", self.before_choice)

    def write_event(self, event):
        path = Path(self.config["log"].get(str))
        with path.open("a") as stream:
            stream.write(json.dumps(event, ensure_ascii=True) + "\n")
            stream.flush()
            os.fsync(stream.fileno())

    def policy(self, task):
        from .import_policy import automatic_choice
        from beetsplug.chroma import _matches

        return automatic_choice(task, _matches, self.recording_evidence)

    def started(self, session, task):
        if task.is_album or not self.config["collect_recording_evidence"].get(bool):
            return
        from beets import plugins
        from .recording_evidence import collect

        enabled = any(plugin.name == "chroma" for plugin in plugins.find_plugins())
        for item in task.items:
            self.recording_evidence[item.path] = (
                collect(item.path)
                if enabled
                else {"error": "Configured chroma collector is unavailable"}
            )
        # Source is the pinned immutable search description, separate from the
        # Item's tags. Exclude its untrusted ID shortcut while retaining tags
        # and recording that ID in the evidence. Quiet+timid is prohibited by beets.
        source = task.source
        self.recording_evidence[task.items[0].path]["source_recording_id"] = source.id
        task.source = source._replace(id="", id_consensus=False)

    def decide(self, task):
        candidate, reason = self.policy(task)
        evidence = [
            {
                "release_id": getattr(match.info, "album_id", None),
                "recording_id": getattr(match.info, "track_id", None),
                "year": getattr(match.info, "year", None),
                "edition": getattr(match.info, "albumdisambig", None),
                "artist": getattr(match.info, "artist", None),
                "album": getattr(match.info, "album", None),
                "title": getattr(match.info, "title", None),
                "tracks": len(getattr(match.info, "tracks", []) or []),
                "distance": float(match.distance),
            }
            for match in (task.candidates or [])[:5]
        ]
        event = {
            "action": "AUTO" if candidate else "REVIEW",
            "album": task.is_album,
            "reason": reason,
            "candidates": evidence,
            "items": [
                {"path": os.fsdecode(item.path), "fields": {}} for item in task.items
            ],
        }
        if not task.is_album:
            from .import_policy import SINGLETON_POLICY_VERSION

            event.update(
                policy=SINGLETON_POLICY_VERSION,
                evidence=self.recording_evidence.get(task.items[0].path, {}),
                native_recommendation=getattr(task.rec, "name", str(task.rec)),
            )
        self.write_event(event)
        return candidate

    def before_choice(self, session, task):
        if not self.config["automatic"].get(bool) or not task.is_album:
            return None
        from beets.importer import Action

        return self.decide(task) or Action.SKIP

    def record(self, task, action):
        fields = [
            "artist",
            "artists",
            "title",
            "albumartist",
            "albumartists",
            "album",
            "year",
            "month",
            "day",
            "track",
            "tracktotal",
            "disc",
            "disctotal",
            "comp",
            "mb_trackid",
            "mb_albumid",
            "mb_artistid",
            "mb_artistids",
            "mb_albumartistid",
            "mb_albumartistids",
            "mb_releasegroupid",
            "mb_releasetrackid",
            "albumdisambig",
            "data_source",
        ]
        if action == "APPLY":
            # Applying sparse provider data over source tags retains old values.
            # Audit the selected match's data, never the resulting Item defaults.
            pairs = (
                task.match.merged_pairs
                if task.is_album
                else [(task.match.item, task.match.info.item_data)]
            )
            if not task.is_album:
                fields = [
                    "artist",
                    "artists",
                    "title",
                    "mb_trackid",
                    "mb_artistid",
                    "mb_artistids",
                    "data_source",
                ]
        else:
            pairs = [(item, {}) for item in task.items]
        event = {
            "action": action,
            "album": task.is_album,
            "items": [
                {
                    "path": os.fsdecode(item.path),
                    "fields": {
                        key: data[key] for key in fields if data.get(key) is not None
                    },
                }
                for item, data in pairs
            ],
        }
        self.write_event(event)

    def applied(self, session, task):
        if task.apply:
            self.record(task, "APPLY")

    def choice(self, session, task):
        if self.config["automatic"].get(bool) and not task.is_album:
            # The pinned singleton UI has no before-choice event. Override the
            # quiet UI's choice before any metadata is applied, using audio evidence.
            from beets.importer import Action

            task.set_choice(self.decide(task) or Action.SKIP)
        action = task.choice_flag.name
        if action != "APPLY":
            self.record(task, action)
