# Security remediation cutover

PR #7228 contains source changes and public regression checks. Activation,
private secret migration and external account settings remain separate steps.
The PR stays draft until the relevant private evaluation and operational
acceptance have been completed.

## Restricted NFS

Blizzard serves NFSv4 over TCP 2049 to these exact clients:

| Export | Client | Access |
|--------|--------|--------|
| `/rpool/enc/transfers` | Snowfall and Avalanche over Tailscale | Read/write |
| `/rpool/unenc/media/data/media` | Snowfall over Tailscale | Read/write for Subgen |
| `/flash/enc/personal/paperless-consumption` | Registered Paperless guest, only when enabled | Read/write for ingestion and removal |

Firefox and Brave have no NFS mounts. The firewall checks the source address,
destination address and ingress interface before Tailscale's INPUT acceptance.
Legacy RPC ports, UDP NFS and IPv6 NFS remain denied. The NFS listeners require
a successful guarded firewall start, and a temporary deny remains during
firewall replacement or failure. The Paperless grant permits only NFS to the
host; host management ports remain denied.

Exports retain root squashing and require reserved client ports. Subtree checks
protect paths that are below a filesystem root; moving open files can cause
stale filehandles with this setting. Before activation, verify each real
mountpoint and the client application's numeric UID/GID, then test read/write,
rename and delete behavior with a disposable file. In particular, Paperless's
consumption directory must permit its existing application identity. No live
ownership, ACL or mode changes are part of this patch.
See [exports(5)](https://www.man7.org/linux/man-pages/man5/exports.5.html)
for the subtree security and rename behavior.

The public `nfs-access` VM check uses disposable directories and synthetic
interfaces. It verifies permitted read/write, per-export denials, root
squashing, source/interface restrictions, legacy protocol denial, Paperless
host-management denial, and firewall failure/recovery. It does not establish
the permissions of the real exports.

## Metrics authority and private bundles

`sys.services.victoriametrics.authorization.enable` prepares a vmauth frontend
on the explicit Tailscale IPv4/port. The database moves to authenticated
loopback. Separate credentials grant ingestion, read-only Grafana queries and
backend authority. The writer can reach only `/api/v1/write`; neither frontend
identity can reach database administration. vmauth's own administrative
endpoints use a private Unix socket. Passwords must be nonempty and distinct.

The feature remains disabled on Blizzard until the private bundles are ready.
The existing authenticated endpoint therefore retains its shared authority
during this preparation; the source module alone does not close that finding.

Create private `secrets/hosts/{blizzard,snowfall,avalanche}.yaml` files and export
them as `nix-secrets.secrets.hosts.<host>`. Each document should be encrypted
only to that host and the selected human recovery recipient. Generate fresh
credentials: ingestion in all three documents, query and backend only in
Blizzard's. Keep the latter two root-owned with mode `0400`; Prometheus receives
only the ingestion password. Do not copy credential values into Nix expressions.

After the private change is reviewed, select the appropriate document through
`sys.secrets.victoriametricsSopsFile` on each host, enable authorization on
Blizzard, and wire `authorization.queryPasswordFile` and `backendPasswordFile`
to their SOPS paths. Move Blizzard's Tailscale readiness ordering to the
`victoriametrics-vmauth` unit. Coordinate the private-input pin with this
change, then evaluate and build the affected hosts before deployment.

Changing any role password restarts the database and frontend so startup
validation also protects direct loopback access against credential reuse.
Query rotation also restarts Grafana; ingestion rotation restarts Prometheus.
The public authorization tests exercise the actual pinned vmauth binary and
generated startup commands with synthetic credentials. Live ingestion and
Grafana queries still require acceptance after cutover.

## Builder and service trust

Remote build submission on Blizzard and Avalanche, and Snowfall's remote
builder server, are disabled pending a separate trusted builder. Snowfall's
unused outbound builder definitions are removed. These source changes take
effect only after their host configurations are activated. A restricted SSH
account does not by itself make remote build results trustworthy.

Media automation still shares writable storage to preserve hardlinks across
downloads, imports and cross-seed. Before restricting it further, map the
writers' exact paths and numeric identities, verify hardlinks remain on one
filesystem and mount, and test import, rename, subtitle and deletion workflows.
Do not replace this with guessed ownership changes or independent mounts that
break hardlinking.

Password verifiers still embedded in the private VARS input require a
coordinated account-schema migration. Remove the inline values and use
root-owned SOPS delivery with `neededForUsers` and `hashedPasswordFile`, then
verify account creation and login with `mutableUsers = false`. Existing
historical exposure and the broad recipients of the general SOPS bundle need
separate rotation and per-service document migration decisions.

## External settings and live acceptance

Use the solo-maintainer GitHub controls in
[reference-ci.md](reference-ci.md#introduction). Environment secrets must be
provisioned through a secure local interface; GitHub cannot return existing
secret values for copying. Coordinate removal of repository-wide secrets with
the workflow cutover so trusted CI does not lose access unexpectedly.

Keep Cloudflare's home-IP bypass, with Blizzard as its sole updater. Before
activation, compare the policy's single address with the current home WAN
address, preserve its application associations, verify Blizzard's ownership
history, and check the other hosts' old updater units are stopped. This patch
does not edit the live policy or establish that its current IP is correct.
Historical CrowdSec bouncer credentials also require issuer-side revocation
evidence before their finding can be closed.
