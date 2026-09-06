{
  lib,
  stdenv,
  fetchFromGitHub,
  meson,
  ninja,
  pkg-config,
  libdrm,
  libglvnd,
  libva,
}:
stdenv.mkDerivation {
  pname = "libdrmtap";
  version = "0.5.4";

  # Must match LIBDRMTAP_SHA_PINNED in the packaged RustDesk build.py.
  src = fetchFromGitHub {
    owner = "rustdesk-org";
    repo = "libdrmtap";
    rev = "5da68a3a368db569716d0d0f11cefacbb11b2290";
    sha256 = "10q9v00i0hgm98wdaz9dvlb94xi38c0c674qgkg5b5qli8639ckp";
  };

  strictDeps = true;
  nativeBuildInputs = [
    meson
    ninja
    pkg-config
  ];
  buildInputs = [
    libdrm
    libglvnd
    libva
  ];
  mesonFlags = [
    "-Dhelper=disabled"
    "-Degl=enabled"
  ];

  # Preserve lazy GPU loading; resolve SONAMEs through immutable store paths.
  postPatch = ''
    substituteInPlace src/gpu_egl.c \
      --replace-fail '"libEGL.so.1"' '"${lib.getLib libglvnd}/lib/libEGL.so.1"' \
      --replace-fail '"libEGL.so"' '"${lib.getLib libglvnd}/lib/libEGL.so"' \
      --replace-fail '"libGLESv2.so.2"' '"${lib.getLib libglvnd}/lib/libGLESv2.so.2"' \
      --replace-fail '"libGLESv2.so"' '"${lib.getLib libglvnd}/lib/libGLESv2.so"'
  '';

  # Hardware integration tests require a real DRM device; the unit suite does not.
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    meson test --print-errorlogs --suite unit
    runHook postCheck
  '';

  # RustDesk only dlopens the shared library. Never ship the privileged helper.
  postInstall = ''
    rm -f "$out/lib/libdrmtap.a"
    test -f "$out/lib/libdrmtap.so.0"
    test ! -e "$out/libexec/drmtap-helper"
  '';

  meta = {
    description = "DRM/KMS capture library for RustDesk unattended Wayland";
    homepage = "https://github.com/rustdesk-org/libdrmtap";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
