{
  lib,
  stdenv,
  pam,
  python3,
  systemd,
  makeWrapper,
  writeText,
  allowedUsers,
  pcrs ? [
    4
    7
  ],
}:
let
  credentialDirectory = "/var/lib/kwallet-tpm";
  configFile = writeText "kwallet-tpm-config.json" (
    builtins.toJSON {
      users = allowedUsers;
      inherit pcrs credentialDirectory;
      systemdCreds = "${systemd}/bin/systemd-creds";
      systemdAnalyze = "${systemd}/bin/systemd-analyze";
    }
  );
  header = writeText "kwallet-tpm-config.h" ''
    #define CREDENTIAL_DIRECTORY ${builtins.toJSON credentialDirectory}
    #define SYSTEMD_CREDS "${systemd}/bin/systemd-creds"
    #define ALLOWED_USERS { ${lib.concatMapStringsSep ", " builtins.toJSON allowedUsers}, NULL }
  '';
in
stdenv.mkDerivation {
  pname = "kwallet-tpm";
  version = "1";
  src = ./.;
  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ pam ];
  strictDeps = true;

  buildPhase = ''
    runHook preBuild
    $CC -std=c11 -O2 -Wall -Wextra -Werror -fPIC -shared \
      -include ${header} pam_kwallet_tpm.c -o pam_kwallet_tpm.so -lpam
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 pam_kwallet_tpm.so "$out/lib/security/pam_kwallet_tpm.so"
    install -Dm644 enroll.py "$out/libexec/kwallet-tpm-enroll.py"
    substituteInPlace "$out/libexec/kwallet-tpm-enroll.py" \
      --replace-fail '@config@' '${configFile}'
    makeWrapper ${python3}/bin/python3 "$out/bin/kwallet-tpm-enroll" \
      --add-flags "$out/libexec/kwallet-tpm-enroll.py" \
      --set PYTHONDONTWRITEBYTECODE 1
    runHook postInstall
  '';

  passthru = { inherit configFile; };

  meta = {
    description = "Local TPM credential enrollment and optional KWallet PAM handoff";
    platforms = lib.platforms.linux;
    mainProgram = "kwallet-tpm-enroll";
  };
}
