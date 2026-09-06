# Local packages

These derivations are explicitly loaded through `packages/default.nix`, outside
the auto-loaded NixOS and Home Manager module trees. Flake outputs expose them
as `packages.x86_64-linux.<name>`.

## RustDesk unattended Wayland

`rustdesk-unattended-wayland` builds RustDesk from commit
`692113c87e476c2e8a82a7cdb9aa98354abc11fc`, with `flutter`, `hwcodec`,
`linux-pkg-config`, `drm`, and `drm-wake`. Its `libdrmtap` 0.5.4 dependency uses
`5da68a3a368db569716d0d0f11cefacbb11b2290`, the exact library revision pinned
by that RustDesk commit's `build.py`.

The Flutter derivation and supporting files originate from
`NixOS/nixpkgs@a5cc6f2c37bf518436dc8d1c288ccd0c43c2f4c4`, directory
`pkgs/by-name/ru/rustdesk-flutter`. Flutter lock metadata and Git hashes were
refreshed from the new RustDesk source and resolved with Flutter 3.29.3
(`flutter pub get`). This updates the analyzer/SDK dependencies that otherwise
fail against Dart 3.7.2; locked Git revisions are unchanged. `extended_text` is
explicitly updated from 14.0.0 to 15.0.2 for Flutter 3.29's selection APIs.
The code generator remains at upstream's 1.80.1. The package has a distinct
name and desktop label.

The Nix adaptation preserves upstream's root-only absolute capture-library
loader and IPC peer checks. The library is loaded from its immutable store
path. The session subprocess re-enters the package wrapper after `sudo`, then
executes the same ELF as the service. This restores loader and command paths
without changing executable identity. EGL/GLES remain lazily loaded; no
privileged capture helper or file capabilities are installed.

Build on x86_64 Linux:

```sh
nix build .#libdrmtap
nix build .#rustdesk-unattended-wayland
```

The library runs upstream's unit suite; hardware-dependent capture tests are
excluded. The application checks the installed ELF for the DRM library path,
display-wake marker, and wrapper path. These do not prove capture on a GPU.

For package-only validation without the private flake input, use an already
fetched checkout of the repository's pinned Nixpkgs:

```sh
nix-build --no-out-link --expr \
  '(import ./packages { pkgs = import /path/to/pinned-nixpkgs {}; }).rustdesk-unattended-wayland'
```

## Updating

1. Select a reviewed RustDesk commit and update `src.rev`, its source hash, and
   the version. Fetch submodules when calculating the source hash.
1. Inspect that commit's `build.py` for features and `LIBDRMTAP_SHA_PINNED`;
   update the library revision, version and source hash together.
1. Apply the package's Flutter compatibility change to `pubspec.yaml`
   (`extended_text: 15.0.2`) if the new source still pins 14.0.0.
   Run `flutter pub get` in that checkout's `flutter` directory using the
   packaged Flutter SDK (currently 3.29.3). Review the lockfile changes and
   confirm Git revisions did not move. Convert the resolved lock with
   `yq . flutter/pubspec.lock > /path/to/package/pubspec.lock.json`.
1. Run `python3 update-git-hashes.py` in the package directory on Linux with
   `nix-prefetch-git` available. It fetches only locked revisions.
1. Temporarily set `cargoDeps.hash` to `lib.fakeHash`, build the `cargoDeps`
   attribute, and replace it with Nix's reported actual hash. Never commit a
   placeholder hash. Check patches and the Flutter/codegen versions against
   upstream before building the complete application.
1. Repeat the host acceptance tests in [the operations guide](../docs/rustdesk-unattended-wayland.md).

Source references:

- [RustDesk build and library pin](https://github.com/rustdesk/rustdesk/blob/692113c87e476c2e8a82a7cdb9aa98354abc11fc/build.py)
- [Privileged loader](https://github.com/rustdesk/rustdesk/blob/692113c87e476c2e8a82a7cdb9aa98354abc11fc/libs/scrap/src/common/drmtap_dl.rs)
- [libdrmtap build](https://github.com/rustdesk-org/libdrmtap/blob/5da68a3a368db569716d0d0f11cefacbb11b2290/meson.build)
