# cross-seed upstream integration reference

Research checked on 2026-11-01. This records upstream behavior for the Blizzard
integration; host placement and rollout settings are owned by the repository
configuration.

## Version and NixOS configuration

The primary `nixos-26.05` nixpkgs revision `fa1373130d5a21c040a47c5dbe1913d59ed91808`
packages cross-seed **6.13.7** with Node.js 22.
([Package source](https://github.com/NixOS/nixpkgs/blob/fa1373130d5a21c040a47c5dbe1913d59ed91808/pkgs/by-name/cr/cross-seed/package.nix))

The pinned NixOS module and the checked `nixos-unstable` module have identical
content, blob `2bf7da6233704a8bc3e781c807fd1d167972ab65`. The module:

- Runs `cross-seed daemon`, with `CONFIG_DIR=/var/lib/cross-seed` by default.
- Supports `settings` for public JSON-compatible options and `settingsFile` for
  runtime JSON containing credentials; there is no `credentialsFile` option.
- Loads `settingsFile` through systemd `LoadCredential` as
  `secretSettingsFile`, then reads it through `CREDENTIALS_DIRECTORY`.
- Merges generated defaults, public settings, and secret settings, in that
  order. This is a shallow JavaScript `Object.assign` merge.
- Defaults `useGenConfigDefaults` to `false`; enabling it imports the package's
  generated template before applying the declared settings.
- Rejects `settings.apiKey` to keep the API key out of the Nix store.
- Creates its config and output directories, but does not create `linkDirs` or
  open firewall ports. It declares mount requirements for data, links, and output.

([Pinned module](https://github.com/NixOS/nixpkgs/blob/fa1373130d5a21c040a47c5dbe1913d59ed91808/nixos/modules/services/torrent/cross-seed.nix),
[upstream module](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/services/torrent/cross-seed.nix))

Operational consequence: a standalone CLI command that loads this generated
config must also have the daemon's credential environment. Merely setting
`CONFIG_DIR` does not satisfy a config that reads `CREDENTIALS_DIRECTORY`.
This follows from the module's generated JavaScript.

## Client and indexers

For qBittorrent, use `torrentClients` entries such as
`qbittorrent:http://USER:PASSWORD@CLIENT:PORT`; encode special characters in
credentials. `useClientTorrents=true` queries the client API and replaces
`torrentDir`; it also supports renamed content and qBittorrent's SQLite mode.
Prowlarr requires one Torznab URL per selected indexer, for example
`http://PROWLARR:9696/INDEXER_ID/api?apikey=KEY`. Its base `/api` URL is not a
Torznab endpoint.
([Options](https://www.cross-seed.org/docs/basics/options#torrentclients))

`action="inject"` adds matches directly to qBittorrent. With Sonarr/Radarr,
enable linking or use `duplicateCategories=true` so cross-seeds do not enter
the ordinary Arr import queue. Never configure the output directory as a torrent
client watch directory.
([Direct client injection](https://www.cross-seed.org/docs/tutorials/injection))

The 6.13.7 template uses `linkCategory="cross-seed-link"`,
`flatLinking=false`, `useClientTorrents=true`, `action="inject"`,
`includeSingleEpisodes=false`, and `includeNonVideos=false`.
([Versioned template](https://github.com/cross-seed/cross-seed/blob/v6.13.7/src/config.template.cjs))

Select eligible private torrent indexers explicitly. Upstream advises against
public trackers as Torznab destinations and does not support magnet-only
results. Existing public torrents can still be sources for private cross-seeds.
Do not automatically include every Prowlarr indexer or any Usenet indexer.
([FAQ](https://www.cross-seed.org/docs/basics/faq-troubleshooting#does-cross-seed-work-on-public-trackers))

## Paths, links, and permissions

Cross-seed and qBittorrent must see existing data and injected links at identical
absolute paths; cross-seed has no path remapping. Both services need compatible
user/group permissions. A common parent mount avoids hardlink failures caused
by separate mountpoints.
([Setup failures](https://www.cross-seed.org/docs/basics/common-setup-failures))

Set `linkDirs` to dedicated directories accessible to both services. Hardlinks
need the same filesystem/mount as the source and survive removal of another
name for the data. Symlinks can cross filesystems but break if originals move
or disappear. Reflinks need filesystem support; avoid `reflinkOrCopy`, which can
silently allocate copies. Separate tracker subdirectories are the default.
([Linking](https://www.cross-seed.org/docs/tutorials/linking))

`dataDirs` is usually unnecessary when the existing torrent client is the data
source. Reserve it for content absent from the client, such as Usenet or an
initial search of a media library; filesystem scans and watches add overhead.
([Data-based matching](https://www.cross-seed.org/docs/tutorials/data-based-matching))

## Matching and automatic downloads

The template defaults to `matchMode="flexible"`, allowing renames. `partial`
also tolerates differing or missing small files, requires linking, and rechecks
injected torrents before deciding whether to resume. It does not make incomplete
or unreadable source files valid.
([Partial matching](https://www.cross-seed.org/docs/tutorials/partial-matching))

`autoResumeMaxDownload=0` resumes only complete matches;
`ignoreNonRelevantFilesToResume=false` avoids the separate allowance for missing
support files. The default maximum is 50 MiB. `skipRecheck=false` requests checks
for all injected torrents; partial matches always require checking.
([Options](https://www.cross-seed.org/docs/basics/options#autoresumemaxdownload))

For the requested full-content-only automatic seeding policy, use:

```nix
matchMode = "flexible";
skipRecheck = false;
autoResumeMaxDownload = 0;
ignoreNonRelevantFilesToResume = false;
```

The 6.13.7 qBittorrent integration adds these torrents stopped, rechecks their
data, and refuses to resume with any bytes missing. A mismatch may remain in
the client stopped for review. `strict` adds filename restrictions; the recheck
provides content verification for either mode.
([qBittorrent integration](https://github.com/cross-seed/cross-seed/blob/v6.13.7/src/clients/QBittorrent.ts),
[resume policy](https://github.com/cross-seed/cross-seed/blob/v6.13.7/src/clients/TorrentClient.ts))

## Scheduling, completion triggers, and API

The daemon starts catalog searches and RSS processing automatically. Standard
defaults are RSS every 30 minutes and daily search batches of 400 unique queries
per indexer. Starting the service therefore has external effects; there is no
separate automatic first-run review stage.
([Getting started](https://www.cross-seed.org/docs/basics/getting-started#4-run-the-daemon))

In 6.13.7, jobs without a previous run recorded in the database are eligible
immediately. `searchCadence=null` and `rssCadence=null` omit those jobs;
`action="inject"` still creates an hourly saved-injection retry job. A service
readiness gate therefore provides a clearer initial staging boundary than
changing the search schedule.
([Scheduler source](https://github.com/cross-seed/cross-seed/blob/v6.13.7/src/jobs.ts),
[search batching source](https://github.com/cross-seed/cross-seed/blob/v6.13.7/src/pipeline.ts))

Download completion webhooks accelerate searching and retry pending injections.
qBittorrent's completion command can POST `infoHash=%I` and
`includeSingleEpisodes=true` to `/api/webhook` while keeping the global
single-episode setting disabled. Without this hook, scheduled searching still
finds completed torrents. Keep `ignoreCrossSeeds` enabled to avoid redundant
completion searches of injected torrents.
([Triggering searches](https://www.cross-seed.org/docs/tutorials/triggering-searches))

The API listens on port 2468. `GET /api/ping` is unauthenticated;
`POST /api/webhook` accepts an API key through the `X-Api-Key` header or an
`apikey` query parameter. Cross-seed generates a key unless explicitly configured;
retrieve it in the daemon's configuration environment with `cross-seed api-key`.
Keep the API private.
([HTTP API](https://www.cross-seed.org/docs/reference/api),
[setup failures](https://www.cross-seed.org/docs/basics/common-setup-failures#docker-networking-and-webhooks))

Optional Sonarr/Radarr URLs with API keys allow media-ID lookups, with text
search fallback. These add API access requirements but do not require access
to their media directories.
([Media-ID searching](https://www.cross-seed.org/docs/tutorials/id-searching))

## Runtime preflight without searching

There is no dedicated config-validation command in 6.13.7. The existing
`cross-seed test-notification` command performs full startup validation, then
sends only its notification; it does not start catalog indexing, searches,
RSS, or scheduled jobs. With `notificationWebhookUrls=[]`, no notification is
sent. This is a source-verified use of the command rather than a separately
documented validation interface.
([Command source](https://github.com/cross-seed/cross-seed/blob/v6.13.7/src/cmd.ts),
[startup validation](https://github.com/cross-seed/cross-seed/blob/v6.13.7/src/startup.ts),
[notification sender](https://github.com/cross-seed/cross-seed/blob/v6.13.7/src/pushNotifier.ts))

Run it with the daemon stopped and the same service user, groups, config,
filesystem access, and systemd credential loading. The NixOS module installs
`config.js` during `ExecStartPre`, so a new preflight unit needs that step too.
Validation initializes the cross-seed database, checks filesystem permissions,
queries Torznab capabilities, and logs into qBittorrent; qBittorrent validation
also creates the cross-seed tag. It does not prove that every catalog source
path is readable or that every hardlink can be created. Validate a representative
source-to-link path separately before enabling the daemon.
([Startup source](https://github.com/cross-seed/cross-seed/blob/v6.13.7/src/startup.ts),
[qBittorrent validation](https://github.com/cross-seed/cross-seed/blob/v6.13.7/src/clients/QBittorrent.ts))

## Decisions before enabling

1. Choose the permitted indexers and confirm their cross-seeding/API rules.
1. Retain the full-content-only policy above unless deliberately changing it.
1. Choose source data scope: existing qBittorrent catalog, or additional files.
1. Choose hardlinks versus symlinks based on verified storage/mount behavior
   and whether cross-seeds should retain data after originals are removed.
1. Choose whether the first activation starts automatic injection immediately,
   or remains gated until credentials and storage permissions are ready.
