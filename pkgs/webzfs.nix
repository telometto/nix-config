{
  lib,
  pkgs,
  fetchFromGitHub,
  python311,
  buildNpmPackage,
  makeWrapper,
}:

let
  pname = "webzfs";
  version = "unstable-2025-01-15";

  python = python311;
  pythonEnv = python.withPackages (
    ps: with ps; [
      fastapi
      uvicorn
      gunicorn
      jinja2
      python-pam
      pydantic
      python-multipart
      aiofiles
      httpx
      python-dotenv
    ]
  );
in
buildNpmPackage {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "webzfs";
    repo = "webzfs";
    rev = "c930c3f29a61121e919c11e84ecbfebf13953df8";
    hash = "sha256-6KF6I+gr7CaQsmzrL0NQPt0IiQAmwV26R+7P7EPhVXI=";
  };

  npmDepsHash = "sha256-J8up4oRdE1Tzi9g1cTejaKBZA9oc2piWOyTopDEZMfw=";

  nativeBuildInputs = [
    makeWrapper
    python
  ];

  buildInputs = [
    pythonEnv
  ];

  dontNpmBuild = false;

  npmBuildScript = "build:css";

  postPatch = ''
    # Copy .env.example to .env
    cp .env.example .env
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt/webzfs

    # Copy application files
    cp -r auth config core services src templates views $out/opt/webzfs/
    cp manage.py run.sh requirements.txt .env $out/opt/webzfs/
    cp -r static $out/opt/webzfs/
    cp -r node_modules $out/opt/webzfs/ || true

    # Make run script executable
    chmod +x $out/opt/webzfs/run.sh

    # Create wrapper script
    mkdir -p $out/bin
    makeWrapper ${pythonEnv}/bin/python $out/bin/webzfs \
      --add-flags "$out/opt/webzfs/manage.py" \
      --prefix PATH : ${
        lib.makeBinPath [
          pkgs.zfs
          pkgs.smartmontools
          pkgs.sanoid
        ]
      } \
      --set WEBZFS_HOME "$out/opt/webzfs" \
      --chdir "$out/opt/webzfs"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Modern web-based management interface for ZFS pools, datasets, snapshots, and SMART disk monitoring";
    homepage = "https://github.com/webzfs/webzfs";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
