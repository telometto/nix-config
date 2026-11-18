# RustDesk on Kaizer

Kaizer uses the pinned RustDesk unattended Wayland package and Blizzard's
RustDesk backend over Tailscale. Snowfall uses the same upstream package
without Kaizer's managed backend layer.

## Configuration and provisioning

[`hosts/kaizer/rustdesk.nix`](../hosts/kaizer/rustdesk.nix) adds a small patch
to the pinned client. Root, SDDM and desktop processes read the same
`/run/rustdesk/server-options` on each backend settings lookup. It overrides
`custom-rendezvous-server`, `relay-server` and `key`; the custom rendezvous
host also determines the effective rendezvous address on port `21116`.
Other options, passwords and device identities retain RustDesk's normal
per-account lifecycle. No Home Manager profile is required.

On each `rustdesk.service` start, systemd loads the SOPS public key as the
`server-key` credential. The root pre-start helper atomically publishes the
backend hostname and key as two lines in the runtime file. Its mode is
`0644` so every client UID can read this **public** information; the decrypted
SOPS key remains root-only, mode `0400`. Neither the key nor a rendered
settings file enters the Nix store. The runtime directory is retained across
restarts so running GUIs keep the last complete settings until replacement.
An empty key or one containing whitespace stops provisioning; a missing or
broken desktop profile cannot fail this pre-start step.

Provision the dedicated input before the first activation:

1. In private `nix-secrets`, export `secrets.rustdeskFile` pointing to
   `secrets/rustdesk.yaml`.
1. Add `rustdesk/blizzard_server_public_key`, using the public half of
   Blizzard's active RustDesk server keypair. This is the client encryption
   Key, separate from RustDesk Pro API credentials.
1. Include Kaizer's current age recipient in this file's `.sops.yaml` rule
   and run `sops updatekeys secrets/rustdesk.yaml` there.
1. Publish the private change, then update this flake's `nix-secrets` lock
   pin to a revision containing both the export and encrypted entry.
1. Preserve the prior per-account settings as described below, then build
   and activate Kaizer through the normal approved deployment procedure.
1. Fully exit independently launched RustDesk GUIs in every desktop account
   and reopen them from the new generation. Repeat this on package upgrades:
   a service restart does not replace GUI processes outside its cgroup.

Force-disabling `sys.services.rustdeskUnattended.enable` removes Kaizer's
credential and unit additions along with the shared service. It does not
require a public-key path or a desktop profile.

## Restart and server-key rotation

A normal service restart regenerates the three managed options from the
current credential. SOPS queues `rustdesk.service` for restart when the
client public key changes. Independently launched GUIs also read the new
runtime layer on subsequent lookups, so a delayed save of an old options
map cannot change the effective managed backend. Restart existing GUIs
after rotation to reconnect any established connections with the new key.

For a server-key rotation:

1. Keep working SSH or console access to both hosts. Preserve the current
   Blizzard server keypair securely and retain the matching private-input
   revision for rollback.
1. Prepare the replacement server keypair on Blizzard and update the client
   public-key entry in private `secrets/rustdeskFile`. Do not put the server
   private key in the client file. If recipients changed, run `sops updatekeys`.
1. Publish and pin that private revision, build the client configuration,
   and arrange a maintenance window to apply the matching server and client
   changes. Do not assume dual-key acceptance; a mismatch interrupts access.
1. Confirm Blizzard is using the replacement keypair, activate the matching
   Kaizer generation, and verify its SOPS-triggered service restart. Restart
   desktop GUIs, then perform both acceptance checks below.
1. Retire the previous server keypair only after those checks pass. If they
   fail, restore the old server keypair and matching client input together.

## Acceptance checks

Run after initial provisioning, a package change, a restart or key rotation:

- Check `systemctl status rustdesk.service` and
  `journalctl -u rustdesk.service -b` for credential, provisioning and
  process-start errors. Check owner/mode with
  `stat -c '%U %a' /run/rustdesk/server-options`; expect `root 644`.
- In a desktop session, confirm ID Server and Relay Server select Blizzard
  and the Key matches its active public key. Establish a real connection
  through that backend and verify video, keyboard and pointer input.
- Log out to the SDDM greeter, restart the service from SSH, and establish
  another real connection. Verify video and input before and after login.
  Boot autologin alone does not exercise this greeter path.
- For a fresh-state test on a disposable installation, start at SDDM with
  no existing root or SDDM RustDesk identity. Confirm backend registration
  without depending on root-to-greeter identity synchronization. Preserve
  existing identities on a deployed machine.

The synthetic flake check `rustdesk-config` covers writer failures, an empty
root/greeter options map, stale desktop saves, runtime key replacement,
unrelated options, disabled-service evaluation and absent Home Manager.
It compiles the pinned configuration getters, not the full Flutter client;
real backend registration and access require the checks above.

## Capture prior settings and roll back

Before first activating this backend policy, make protected copies of each
existing `RustDesk2.toml`: root's, SDDM's and every desktop account that uses
RustDesk. The usual root path is `/root/.config/rustdesk/RustDesk2.toml`.
Find SDDM's home with `getent passwd sddm`; its usual configuration path is
`<sddm-home>/.config/rustdesk/RustDesk2.toml`. For desktop accounts use their
effective `$XDG_CONFIG_HOME/rustdesk/RustDesk2.toml`, or
`~/.config/rustdesk/RustDesk2.toml` when unset. Record an absent file too.
Keep copies in a root-only backup directory outside the repository, using
`sudo install -m 0600 <profile-path> <backup-path>` for each existing file.

The new helper never edits those profiles, but RustDesk itself can persist
effective settings during normal saves. The earlier profile-writing
implementation also persists its changes. A generation rollback alone
therefore does not establish the previous backend settings.

To remove the policy or roll back:

1. Keep SSH or console access, stop `rustdesk.service`, and fully exit
   RustDesk GUIs in every desktop account so no cached writer remains.
1. Select a generation without this backend policy and activate it through
   the approved rollback procedure. Stop its service again while restoring
   profiles.
1. In each account's current `RustDesk2.toml`, restore only the prior
   top-level `rendezvous_server` and the `[options]` entries
   `custom-rendezvous-server`, `relay-server` and `key` from the protected
   copy. Remove an entry if it was previously absent. If the entire file
   was absent, remove these four entries from any newly created profile.
   Preserve current device IDs, passwords, unrelated settings, ownership
   and permissions; do not replace the entire profile with an old copy.
1. With the managed unit stopped, remove any leftover
   `/run/rustdesk/server-options`. Start the prior service and reopen GUIs
   from the selected generation, then verify session and greeter access
   against the intended backend.

For a key rotation rollback, also restore Blizzard's prior server keypair
and pin the matching client public-key input. Keep the managed layer enabled
when rolling back only the keypair; its next service start republishes the
matching settings.
