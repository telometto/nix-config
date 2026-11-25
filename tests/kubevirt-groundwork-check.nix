{
  nixpkgs,
  system ? "x86_64-linux",
}:
let
  pkgs = import nixpkgs { inherit system; };
  contract = import ./kubevirt-groundwork.nix { inherit nixpkgs system; };
in
assert contract.passed;
pkgs.runCommand "kubevirt-groundwork-contract"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.nix
    ];
  }
  ''
    mkdir -p work/lib/kubevirt-groundwork work/tests/kubevirt_groundwork
    cp ${../lib/kubevirt-groundwork/catalog.json} work/lib/kubevirt-groundwork/catalog.json
    cp ${../lib/kubevirt-groundwork/contract.nix} work/lib/kubevirt-groundwork/contract.nix
    cp ${../lib/kubevirt-groundwork/generate.py} work/lib/kubevirt-groundwork/generate.py
    cp ${./kubevirt_groundwork/test_generator.py} work/tests/kubevirt_groundwork/test_generator.py
    PYTHONDONTWRITEBYTECODE=1 python -m unittest discover -s work/tests/kubevirt_groundwork -v
    touch "$out"
  ''
