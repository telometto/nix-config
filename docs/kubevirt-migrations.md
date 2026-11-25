# MicroVM migration queue

The common host base now provides a disabled-by-default, namespaced retained-disk
registry. The SearxNG preview provides the first service blueprint: suspended
Flux storage/app layers, pinned Debian + app images, private access, a per-boot
public configuration ISO and a guest-local identity. It does not introduce a
universal guest operator or a production-data import tool.

SearxNG is the existing runtime-tested preview. The expanded batch prepares a
separate `dev/kubevirt-<service>` branch and paired draft PRs for every other
eligible enabled MicroVM, including services whose runtime implementation still
needs live tests. Groundwork is explicitly halted, disabled and suspended; it is
not application acceptance. Each service receives an owned implementation area
and agent checklist. Keep each production MicroVM/route as rollback and use fresh
preview volumes until a separate data-migration gate is approved.

The user no longer uses Plex. Tautulli is excluded because it is Plex-only.
Seerr remains eligible because it supports Jellyfin; preserve the legacy
`overseerr` VM/state identity during eventual migration.

This inventory comes from the public enabled VM declarations, not from reading
running application data or secret files. A declared running VM does not prove
its application has already moved off the host; Jellyfin retains its own gate.

| Order / workload | State and integration boundary | Next implementation or deployment prerequisite |
|------------------|--------------------------------|-----------------------------------------------|
| 1. SearxNG | Fresh root and signing key; disposable guest-local cache; public search egress | `dev/kubevirt-searxng` prepared in both repos. Deploy the private preview only after review; validate real Flux/CDI/config ISO and Git stop/start before runtime acceptance of additional services. |
| Tautulli — excluded | Plex-only monitoring | Skip its KubeVirt migration. This preparation does not retire or stop the existing VM. |
| 2. Overseerr / Seerr | `/var/lib/overseerr`; existing automatic Seerr schema transition; Jellyfin and Sonarr/Radarr access | Preserve the existing migration/version boundary, authorize isolated API peers, then test a stopped copy of state. Do not run a second writer against production state. |
| 3. Prowlarr | Private state, indexer credentials, FlareSolverr and reciprocal Arr connections | Add two guest services, strict peer policies and a credential-delivery plan; validate a fresh private instance before copying any indexer state. |
| Sonarr | `/var/lib/sonarr`, media share, Prowlarr and download-client APIs | Prove media UID/GID/ACL and path parity, private peers and independent database restore. |
| Radarr | `/var/lib/radarr`, media share, Prowlarr and download-client APIs | Same filesystem and API acceptance as Sonarr; prepare its own branch and volumes. |
| Readarr | `/var/lib/readarr`, media share and download-client APIs | Validate supported application image/version and filesystem/API parity before state transfer. |
| Bazarr | `/var/lib/bazarr`, writable media/subtitles, Sonarr/Radarr APIs | Verify subtitle write ownership and exact media paths with a disposable copy first. |
| SABnzbd | `/var/lib/sabnzbd`, media/download paths, provider configuration and return routes | Confirm temporary/incomplete download storage, secrets delivery, ACLs and controlled private egress. |
| qBittorrent | `/var/lib/qbittorrent`, torrent payloads, VPN routing/forwarded torrent port | Requires WireGuard policy design, fail-closed leak tests, port forwarding and path-preserving stopped state transfer. |
| cross-seed | Application state, media hardlinks, qBittorrent and Prowlarr credentials | Preserve complete-content-only injection, hardlink/ACL checks and API verification; never point an unverified preview at production automation. |
| Firefox | Browser profile, container storage, downloads/transfer share, login credentials and VPN return routes | Design guest credentials and browser isolation, NFS/transfer ownership and VPN access before any profile copy. |
| WireGuard | Network gateway, private key, DNS/NAT, kill switch and qBittorrent return routes | Separate network migration with fail-closed, reconnect/reboot and leak acceptance. It cannot use public-web-only preview egress. |
| Gitea | Git repositories, LFS, PostgreSQL and application secrets | Database-consistent export/restore, SSH/HTTP identity and credential-delivery design; retain production writers until a scheduled cutover. |
| Pocket ID | Identity database/uploads and encryption key; downstream login availability | Preserve encryption/signing identity with explicit secret authorization and a tested isolated restore. Public auth cutover is its own gate. |
| Matrix Synapse | Persistent database, signing identity, media, federation and bridge dependencies | Preserve signing identity, database consistency and federation/bridge behavior; public endpoint cutover and rollback need dedicated acceptance. |
| Immich | PostgreSQL, photo library, OIDC and remote machine-learning proxy | Validate library/DB consistency and mount permissions, Pocket ID integration and the existing ML relay without duplicating writes. |
| Jellyfin | Separate host-to-MicroVM gate, media/library state, GPU and LAN/VPS ingress | First resolve the current service-location gate, then design KubeVirt device passthrough and retained-state restore; prove LAN/VPS client behavior separately. |

Actual's private pilot is the existing validated platform reference. Its original
MicroVM declaration is disabled; it is not another running production VM to
convert in this batch. Disabled registry workloads such as AdGuard, Ombi, Lidarr,
Paperless, Firefly, Mealie and Trigger are outside this running-workload queue.

The first live gate is SearxNG deployment on Blizzard. Source/unit/schema tests
and a host closure build can prepare it, but cannot establish real launcher
networking, CDI import or live Flux reconciliation. The next complex gates are
credential delivery, private inter-application access, filesystem ownership,
stopped data restore, VPN behavior and GPU devices. Do not weaken the private
network policy to make these services appear ready.

Off-host backup implementation is deferred by request. Revisit the rsync.net
backup/restore plan before migrating any production state or retiring a MicroVM.
