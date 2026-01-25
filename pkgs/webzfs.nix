{
  lib,
  pkgs,
  fetchFromGitHub,
  python311,
  nodejs,
  fetchNpmDeps,
  npmHooks,
}:

python311.pkgs.buildPythonApplication rec {
  pname = "webzfs";
  version = "unstable-2025-01-15";
  format = "other";

  src = fetchFromGitHub {
    owner = "webzfs";
    repo = "webzfs";
    rev = "c930c3f29a61121e919c11e84ecbfebf13953df8";
    hash = "sha256-6KF6I+gr7CaQsmzrL0NQPt0IiQAmwV26R+7P7EPhVXI=";
  };

  npmDeps = fetchNpmDeps {
    inherit src;
    hash = "sha256-J8up4oRdE1Tzi9g1cTejaKBZA9oc2piWOyTopDEZMfw=";
  };

  nativeBuildInputs = [
    nodejs
    npmHooks.npmConfigHook
  ];

  propagatedBuildInputs = with python311.pkgs; [
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
  ];

  postPatch = ''
    # Copy .env.example to .env
    cp .env.example .env
  '';

  preBuild = ''
    # Build Tailwind CSS assets
    npm run build:css
  '';

  installPhase = ''
        runHook preInstall

        mkdir -p $out/opt/webzfs

        # Copy application files
        cp -r auth config core services src templates views $out/opt/webzfs/
        cp manage.py run.sh requirements.txt .env $out/opt/webzfs/
        cp -r static $out/opt/webzfs/

        # Make run script executable
        chmod +x $out/opt/webzfs/run.sh

        # Create wrapper script
        mkdir -p $out/bin
        cat > $out/bin/webzfs <<'EOF'
    #!${python311}/bin/python
    import sys
    import os

    # Set working directory
    os.chdir("$out/opt/webzfs")
    os.environ["WEBZFS_HOME"] = "$out/opt/webzfs"

    # Add ZFS tools to PATH
    current_path = os.environ.get("PATH", "")
    zfs_tools_path = "${
      lib.makeBinPath [
        pkgs.zfs
        pkgs.smartmontools
        pkgs.sanoid
      ]
    }"
    os.environ["PATH"] = f"{zfs_tools_path}:{current_path}"

    # Import and run the app
    sys.path.insert(0, "$out/opt/webzfs")
    exec(open("$out/opt/webzfs/manage.py").read())
    EOF
        chmod +x $out/bin/webzfs

        runHook postInstall
  '';

  # Don't create .pyc files
  dontUsePythonImportsCheck = true;
  dontUsePythonCatchConflicts = true;

  meta = with lib; {
    description = "Modern web-based management interface for ZFS pools, datasets, snapshots, and SMART disk monitoring";
    homepage = "https://github.com/webzfs/webzfs";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
