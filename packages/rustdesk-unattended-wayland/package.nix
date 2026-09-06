{
  lib,
  clangStdenv,
  cargo,
  copyDesktopItems,
  fetchFromGitHub,
  flutter329,
  ffmpeg_7,
  gst_all_1,
  fuse3,
  libxtst,
  libaom,
  libopus,
  libpulseaudio,
  libva,
  libvdpau,
  libvpx,
  libxkbcommon,
  libyuv,
  pam,
  makeDesktopItem,
  rustPlatform,
  libayatana-appindicator,
  rustc,
  rustfmt,
  xdotool,
  xdg-user-dirs,
  pipewire,
  cargo-expand,
  yq,
  callPackage,
  addDriverRunpath,
  perl,
  openssl,
  libdrmtap,
  libglvnd,
  systemd,
  procps,
  coreutils,
  util-linux,
  gnugrep,
  gnused,
  which,
  xdg-utils,
}:
let
  flutterRustBridge = rustPlatform.buildRustPackage rec {
    pname = "flutter_rust_bridge_codegen";
    version = "1.80.1"; # https://github.com/rustdesk/rustdesk/blob/1.4.4/.github/workflows/bridge.yml#L10

    src = fetchFromGitHub {
      owner = "fzyzcjy";
      repo = "flutter_rust_bridge";
      rev = "v${version}";
      hash = "sha256-SbwqWapJbt6+RoqRKi+wkSH1D+Wz7JmnVbfcfKkjt8Q=";
    };

    patches = [
      ./update-flutter-dev-path.patch
    ];

    cargoHash = "sha256-4khuq/DK4sP98AMHyr/lEo1OJdqLujOIi8IgbKBY60Y=";
    cargoBuildFlags = [
      "--package"
      "flutter_rust_bridge_codegen"
    ];
    doCheck = false;
  };

  ffigen = callPackage ./ffigen {
    flutter = flutter329;
  };

  sharedLibraryExt = rustc.stdenv.hostPlatform.extensions.sharedLibrary;

in
flutter329.buildFlutterApplication rec {
  pname = "rustdesk-unattended-wayland";
  version = "1.5.0-unstable-2026-09-06";

  src = fetchFromGitHub {
    owner = "rustdesk";
    repo = "rustdesk";
    rev = "692113c87e476c2e8a82a7cdb9aa98354abc11fc";
    fetchSubmodules = true;
    hash = "sha256-Rm2nnQiPDj0Ou3Gbn7QMC0Jtyg6Bd+885RmfmyLD6RQ=";
  };

  strictDeps = true;
  # hwcodec expects this variable even when using system libraries.
  env.VCPKG_ROOT = "/homeless-shelter";
  env.OPENSSL_NO_VENDOR = true;

  # Configure the Flutter/Dart build
  sourceRoot = "${src.name}/flutter";
  # Upstream lock resolved with Flutter 3.29.3; see ../README.md.
  pubspecLock = lib.importJSON ./pubspec.lock.json;
  gitHashes = lib.importJSON ./git-hashes.json;

  # Configure the Rust build
  cargoRoot = "..";
  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit
      pname
      version
      src
      patches
      ;
    hash = "sha256-7Sy/KluDF8xSAdUmrO3QWDrlrfDL+JNFBJtREvETgsQ=";
  };

  dontCargoBuild = true;
  cargoBuildFlags = "--lib";
  cargoBuildType = "release";
  cargoBuildFeatures = [
    "flutter"
    "hwcodec"
    "linux-pkg-config"
    "drm"
    "drm-wake"
  ];

  nativeBuildInputs = [
    # flutter_rust_bridge_codegen
    cargo
    copyDesktopItems
    rustfmt
    # Rust
    rustPlatform.cargoSetupHook
    rustPlatform.cargoBuildHook
    cargo-expand
    rustPlatform.bindgenHook
    ffigen
    yq
    perl
  ];

  buildInputs = [
    ffmpeg_7
    fuse3
    gst_all_1.gst-plugins-base
    gst_all_1.gstreamer
    libxtst
    libaom
    libopus
    libpulseaudio
    libva
    libvdpau
    libvpx
    pipewire
    libxkbcommon
    libyuv
    pam
    xdotool
    openssl
  ];

  prePatch = ''
    chmod -R +w ..
    cd ..
  '';

  patches = [
    ./make-build-reproducible.patch
    ./reenter-wrapper.patch
  ];

  prepareBuildRunner = ''
    cp ${./build-runner.sh} build_runner
    substituteInPlace build_runner \
      --replace-fail "@bash@" "$SHELL"
    chmod +x build_runner
    export PATH=$PATH:$PWD
  '';

  postPatch = ''
    # Keep the root-only absolute-path loader and all IPC peer checks intact.
    substituteInPlace libs/scrap/src/common/drmtap_dl.rs \
      --replace-fail '/usr/lib/rustdesk/libdrmtap.so.0' '${libdrmtap}/lib/libdrmtap.so.0'
    substituteInPlace src/platform/linux.rs \
      --replace-fail '@rustdesk-wrapper@' '${placeholder "out"}/bin/rustdesk' \
      --replace-fail 'Command::new("sudo")' 'Command::new("/run/wrappers/bin/sudo")'
    cd flutter
    # Flutter 3.29 adds SelectionHandler APIs absent from extended_text 14.
    substituteInPlace pubspec.yaml \
      --replace-fail 'extended_text: 14.0.0' 'extended_text: 15.0.2'
    if [ $cargoDepsCopy ]; then # That will be inherited to buildDartPackage and it doesn't have cargoDepsCopy
      substituteInPlace $cargoDepsCopy/*/libappindicator-sys-*/src/lib.rs \
        --replace-fail "libayatana-appindicator3.so.1" "${lib.getLib libayatana-appindicator}/lib/libayatana-appindicator3.so.1"
      # Disable static linking of ffmpeg since https://github.com/21pages/hwcodec/commit/1873c34e3da070a462540f61c0b782b7ab15dc84
      sed -i 's/static=//g' $cargoDepsCopy/*/hwcodec-*/build.rs
      sed -e '1i #include <cstdint>' -i $cargoDepsCopy/*/webm-1.1.0/src/sys/libwebm/mkvparser/mkvparser.cc
      sed -e '1i #include <cstdint>' -i $cargoDepsCopy/*/webm-sys-1.0.4/libwebm/mkvparser/mkvparser.cc
    fi

    substituteInPlace ../Cargo.toml --replace-fail ", \"staticlib\", \"rlib\"" ""
  '';

  preBuild = ''
    # Build the Flutter/Rust bridge bindings
    cat <<EOF > bridge.yml
    rust_input:
      - "../src/flutter_ffi.rs"
    dart_output:
      - "./lib/generated_bridge.dart"
    llvm_path:
      - "${lib.getLib clangStdenv.cc.cc}"
    dart_format_line_length: 80
    llvm_compiler_opts: "-I ${lib.getLib clangStdenv.cc.cc}/lib/clang/${lib.versions.major clangStdenv.cc.version}/include -I ${clangStdenv.cc.libc_dev}/include"
    EOF
    runHook prepareBuildRunner
    RUST_LOG=info ${flutterRustBridge}/bin/flutter_rust_bridge_codegen bridge.yml

    # Build the Rust shared library
    cd ..
    preBuild=() # prevent loops
    cargoBuildHook
    mv ./target/*/release/liblibrustdesk${sharedLibraryExt} ./target/release/liblibrustdesk${sharedLibraryExt}
    cd flutter
  '';

  postInstall = ''
    mkdir -p $out/share/polkit-1/actions $out/share/icons/hicolor/{256x256,scalable}/apps
    cp ../res/128x128@2x.png $out/share/icons/hicolor/256x256/apps/rustdesk.png
    cp ../res/scalable.svg $out/share/icons/hicolor/scalable/apps/rustdesk.svg
  '';

  # Equivalent to upstream's staged-binary checks, using the patched Nix path.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    rustLibrary="$out/app/$pname/lib/librustdesk.so"
    test -x "$out/bin/rustdesk"
    test -f "$rustLibrary"
    grep -aFq '${libdrmtap}/lib/libdrmtap.so.0' "$rustLibrary"
    grep -aFq 'enable-drm-display-wake' "$rustLibrary"
    grep -aFq "$out/bin/rustdesk" "$rustLibrary"
    if grep -aFq '/usr/lib/rustdesk/libdrmtap.so.0' "$rustLibrary"; then
      echo 'Unpatched DRM loader path in RustDesk' >&2
      exit 1
    fi
    runHook postInstallCheck
  '';

  extraWrapProgramArgs = ''
    --prefix LD_LIBRARY_PATH : ${addDriverRunpath.driverLink}/lib \
    --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libglvnd ]} \
    --prefix PATH : ${
      lib.makeBinPath [
        xdg-user-dirs
        systemd
        procps
        coreutils
        util-linux
        gnugrep
        gnused
        which
        xdg-utils
      ]
    }
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "rustdesk";
      desktopName = "RustDesk (Unattended Wayland)";
      genericName = "Remote Desktop";
      comment = "Remote Desktop";
      exec = "rustdesk %u";
      icon = "rustdesk";
      terminal = false;
      type = "Application";
      startupNotify = true;
      categories = [
        "Network"
        "RemoteAccess"
        "GTK"
      ];
      keywords = [ "internet" ];
      actions.new-window = {
        name = "Open a New Window";
        exec = "rustdesk %u";
      };
    })
    (makeDesktopItem {
      name = "rustdesk-link";
      desktopName = "RustDeskURL Scheme Handler";
      noDisplay = true;
      mimeTypes = [ "x-scheme-handler/rustdesk" ];
      tryExec = "rustdesk";
      exec = "rustdesk %u";
      icon = "rustdesk";
      terminal = false;
      type = "Application";
      startupNotify = false;
    })
  ];

  meta = {
    description = "RustDesk with DRM capture and display wake for unattended Wayland access";
    homepage = "https://rustdesk.com";
    changelog = "https://github.com/rustdesk/rustdesk/commits/${src.rev}";
    license = lib.licenses.agpl3Only;
    maintainers = with lib.maintainers; [
      das_j
      helsinki-Jo
    ];
    mainProgram = "rustdesk";
    platforms = [ "x86_64-linux" ];
  };
}
