{ pkgs, snowfall }:
let
  cfg = snowfall.config;
  descriptors = [
    "50-edk2-i386-secure.json"
    "50-edk2-x86_64-secure.json"
    "60-edk2-i386.json"
    "60-edk2-x86_64.json"
  ];
  manifest = pkgs.writeText "libvirt-firmware-manifest.json" (
    builtins.toJSON {
      images = cfg.environment.etc."qemu/firmware-images".source;
      upstream = "${cfg.virtualisation.libvirtd.qemu.package}/share/qemu/firmware";
      installed = builtins.listToAttrs (
        map (name: {
          inherit name;
          value = cfg.environment.etc."qemu/firmware/10-${name}".source;
        }) descriptors
      );
    }
  );
in
pkgs.runCommand "libvirt-firmware-contract"
  {
    nativeBuildInputs = [
      pkgs.python3
      cfg.virtualisation.libvirtd.qemu.package
    ];
  }
  ''
    python3 - ${manifest} <<'PY'
    import json
    import pathlib
    import subprocess
    import sys

    def run(*args):
        return subprocess.check_output(args, text=True)

    manifest = json.loads(pathlib.Path(sys.argv[1]).read_text())
    images = pathlib.Path(manifest["images"])
    checked = set()
    for name, installed in manifest["installed"].items():
        original = json.loads((pathlib.Path(manifest["upstream"]) / name).read_text())
        actual = json.loads(pathlib.Path(installed).read_text())
        for key in ("executable", "nvram-template"):
            source = original["mapping"][key]
            target = actual["mapping"][key]
            assert source["format"] == "raw", (name, key, source)
            assert target["format"] == "qcow2", (name, key, target)
            path = pathlib.PurePosixPath(target["filename"])
            assert str(path.parent) == "/etc/qemu/firmware-images", path
            image = images / path.name
            assert image.is_file(), image
            info = json.loads(run("qemu-img", "info", "--output=json", str(image)))
            assert info["format"] == "qcow2", info
            assert "backing-filename" not in info, info
            run("qemu-img", "compare", "-f", "raw", "-F", "qcow2", source["filename"], str(image))
            if image not in checked:
                run("qemu-img", "check", "-f", "qcow2", str(image))
                checked.add(image)
            del original["mapping"][key]
            del actual["mapping"][key]
        assert actual == original, (name, "upstream metadata changed")
    assert set(images.iterdir()) == checked, "unreferenced output images"
    print(f"Validated {len(manifest['installed'])} descriptors and {len(checked)} images")
    PY
    touch "$out"
  ''
