# RustDesk unattended Wayland on Kaizer

Kaizer enables `sys.services.rustdeskUnattended.enable`. This installs the
local DRM-enabled RustDesk package system-wide and starts `rustdesk.service`
as root at boot. The service manages the desktop-user subprocess as sessions
change. `uinput` is loaded for remote keyboard and pointer injection. No
additional desktop-client firewall ports are opened by this module.

The existing `services.rustdesk-server` configuration is the separate
ID/relay backend (`hbbs`/`hbbr`). It does not capture the desktop.

## Recorded validation (2026-09-06)

Using the repository's pinned Nixpkgs
`a5cc6f2c37bf518436dc8d1c288ccd0c43c2f4c4` in an isolated x86_64 Linux
Podman container:

- The complete RustDesk package built successfully, including its installed
  DRM, display-wake, and wrapper-path assertions.
- The installed `rustdesk --version` command exited successfully with `1.5.0`.
- `libdrmtap` built and passed all nine hardware-independent unit tests.
- The NixOS module check passed for disabled, enabled, and overridden-package
  configurations. Focused Nix/Python lint, formatting, and whitespace checks passed.

The build container is named `codex-rustdesk-nix`; its Nix store and build logs
are retained for reuse. The successful application log is
`/tmp/rustdesk-verified-build.log` inside that container.

The full Kaizer configuration was not evaluated or built because the isolated
builder has no SSH access to the private input. No host configuration was
activated. SDDM, NVIDIA capture, session handover, input, and display wake still
require the acceptance checks below on the actual machine.

## Initial setup and rollout

Build the package and Kaizer configuration on a Linux builder before rollout:

```sh
nix build .#rustdesk-unattended-wayland
nix build .#nixosConfigurations.kaizer.config.system.build.toplevel
```

Host evaluation requires access to the private `nix-secrets` input. Activation
is a separate operator action. Keep an SSH or local recovery path available
for the first hardware test.

After activation, configure the server/key and permanent password through
RustDesk's security settings, unlocking settings when requested. Confirm that
password-based access is enabled. Passwords must remain in RustDesk's protected
runtime configuration or the secret system, never a Nix string/store path.
An existing per-user configuration is not proof that the root service has
the intended settings: verify the advertised ID and authentication remotely.

The installed desktop menu entry is **RustDesk (Unattended Wayland)**. Remove
any separately installed Flatpak or user-managed RustDesk instance before
testing if one exists; multiple versions can conflict over IPC and identity.
The previous Home Manager `rustdesk-flutter` package is replaced by the
system-wide package in this repository.

## Acceptance on the actual host

Inspect service status and logs:

```sh
systemctl status rustdesk
journalctl -u rustdesk -b
```

From another machine, verify:

1. Connect with the configured password while a Plasma Wayland user is logged
   in; check video, keyboard and pointer control.
1. Lock and unlock the session remotely.
1. Log out, reconnect to SDDM, and log in remotely; repeat for another enabled
   user to check session handover.
1. Reboot and connect at SDDM before anybody logs in locally.
1. Let the display enter power-saving mode, then reconnect and verify wake
   and capture. Repeat with every connected monitor.
1. Restart the service and confirm its old session children exit and the
   connection can be re-established.

Record GPU/driver, compositor, and package revision with results. A successful
build does not establish NVIDIA scanout compatibility, display-wake behavior,
or headless operation without a usable output/CRTC. Check RustDesk logs for
DRM capture versus fallback to portal/PipeWire capture when diagnosing.

## Service scope and rollback

The privileged service follows upstream's architecture: it needs host devices,
session visibility and privilege to capture DRM scanout and inject input.
Do not add `PrivateDevices`, `PrivateUsers`, `DynamicUser` or capability
restrictions without testing that architecture. The IPC peer authorization
checks are preserved. Stop uses the systemd control group to include child
processes, avoiding upstream's global `pkill` pattern.

Disable `sys.services.rustdeskUnattended.enable` and rebuild through the normal
operator workflow to remove the service and system package. Restore the
ordinary desktop package explicitly if wanted. A previous NixOS generation
also provides configuration rollback. Runtime RustDesk settings are not
deleted by disabling the service.

See [local package maintenance](../packages/README.md) for pins, build details,
and updating instructions.
