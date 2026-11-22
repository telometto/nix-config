{
  lib,
  stdenvNoCC,
  makeWrapper,
  python3,
  restic,
  openssh,
  systemd,
}:
stdenvNoCC.mkDerivation {
  pname = "security-log-archive";
  version = "0.1.0";
  src = ./.;
  nativeBuildInputs = [ makeWrapper ];
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p $out/libexec/security-log-archive $out/bin
    cp archive.py model.py $out/libexec/security-log-archive/
    makeWrapper ${python3}/bin/python3 $out/bin/security-log-archive \
      --add-flags $out/libexec/security-log-archive/archive.py \
      --prefix PATH : ${
        lib.makeBinPath [
          restic
          openssh
          systemd
        ]
      }
    runHook postInstall
  '';
  meta = {
    description = "Bounded, allowlisted security-journal archive and independent recovery";
    mainProgram = "security-log-archive";
    platforms = lib.platforms.linux;
  };
}
