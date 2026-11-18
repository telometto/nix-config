# RustDesk upstream unattended Wayland package assessment

Checked 2026-10-24 against GitHub PR metadata, the linked discussion, upstream
source, and this repository's RustDesk configuration.

## Decision

Keep the existing pinned unattended package. The comment means that the
**source code** for unattended Wayland is now in the stable RustDesk 1.5.0 tag.
It does not mean that Nixpkgs' ordinary `rustdesk-flutter` package enables it.
The comment explicitly proposes retaining a separate variant with the DRM
features, library, loader substitution, wrapper, and tests.
([Linked comment](https://github.com/NixOS/nixpkgs/pull/561724#issuecomment-6317179325))

## Verified upstream facts

- [Nixpkgs PR #561724](https://github.com/NixOS/nixpkgs/pull/561724) is open and
  unmerged. Its head is `86fb8aca9dcd694480c58b087dc73f8b1ed5d38b`; it adds a
  separate `rustdesk-flutter-nightly` package from RustDesk snapshot
  `22b1ed169aa473b320e338c546f1f7b9a511f23f`.
- RustDesk tag `1.5.0` resolves to
  [`fada664df7a294d1d1a9ca3e7cd3637069122f17`](https://github.com/rustdesk/rustdesk/commit/fada664df7a294d1d1a9ca3e7cd3637069122f17).
  It defines `drm` and `drm-wake` as optional features; the default feature is
  `use_dasp`. The DRM capturer is compiled only when `drm` is enabled.
  ([Cargo features](https://github.com/rustdesk/rustdesk/blob/fada664df7a294d1d1a9ca3e7cd3637069122f17/Cargo.toml#L23-L39),
  [capturer compilation gate](https://github.com/rustdesk/rustdesk/blob/fada664df7a294d1d1a9ca3e7cd3637069122f17/src/server.rs#L47-L48))
- Upstream's `build.py --drm` enables both `drm` and `drm-wake`, and uses
  libdrmtap 0.5.8 at `95d4d74549631aa5c39461300acfd2e106583cc9`.
  Upstream's workflow builds this as the separate
  `rustdesk-unattended-wayland` artifact.
  ([Build features and library pin](https://github.com/rustdesk/rustdesk/blob/fada664df7a294d1d1a9ca3e7cd3637069122f17/build.py#L325-L395),
  [separate workflow](https://github.com/rustdesk/rustdesk/blob/fada664df7a294d1d1a9ca3e7cd3637069122f17/.github/workflows/flutter-build.yml#L2039-L2162))
- Ordinary Nixpkgs `rustdesk-flutter` 1.5.0 enables only `flutter`, `hwcodec`,
  and `linux-pkg-config`; it supplies neither libdrmtap nor the DRM loader
  substitution or session-wrapper patch. This was verified at the repository's
  locked `nixpkgs-master` revision and again against current upstream master.
  ([Locked package](https://github.com/NixOS/nixpkgs/blob/bd48d87c50e892d099645f48e702dda37a101513/pkgs/by-name/ru/rustdesk-flutter/package.nix),
  [upstream package at checked master](https://github.com/NixOS/nixpkgs/blob/2c8f089cd7e141e885d6cf7be64c7497fd469d48/pkgs/by-name/ru/rustdesk-flutter/package.nix))
- The DRM path uses a root capture service, DRM devices, and `uinput` for
  input. Its runtime loader uses `/usr/lib/rustdesk/libdrmtap.so.0`; root does
  not try library-search-path fallbacks. The PR includes a Nix store path
  substitution and a wrapper patch for session subprocesses launched through
  `sudo`, so merely adding Cargo flags is insufficient on NixOS.
  ([PR package and README](https://github.com/NixOS/nixpkgs/pull/561724/files),
  [stable loader](https://github.com/rustdesk/rustdesk/blob/fada664df7a294d1d1a9ca3e7cd3637069122f17/libs/scrap/src/common/drmtap_dl.rs#L251-L277))

## Repository consequence and validation limits

[`hosts/snowfall/rustdesk.nix`](../hosts/snowfall/rustdesk.nix) and
[`hosts/kaizer/rustdesk.nix`](../hosts/kaizer/rustdesk.nix) explicitly select
`nixpkgs-rustdesk`'s nightly package. The shared
[`rustdesk-unattended.nix`](../modules/services/rustdesk-unattended.nix) already
supplies a root `rustdesk --service`, `uinput`, and `sudo`.

Changing these selections to plain `pkgs.rustdesk-flutter` would remove the
DRM build support. Rebasing the custom variant onto stable 1.5.0 could reduce
its duplicated packaging, but would still require maintaining the variant.
The requested upstream-package substitution is therefore skipped.

This assessment is based on source and configuration inspection. No package
was built, no configuration was activated, and no greeter, lock-screen,
display-wake, GPU, or session-transition behavior was tested in this task.
