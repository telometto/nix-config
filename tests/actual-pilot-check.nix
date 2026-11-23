{
  nixpkgs,
  system ? "x86_64-linux",
}:
let
  pkgs = import nixpkgs { inherit system; };
  contract = import ./actual-pilot.nix { inherit nixpkgs system; };
  python = pkgs.python3.withPackages (p: [ p.pyyaml ]);
in
assert contract.passed;
pkgs.runCommand "actual-pilot-contract"
  {
    nativeBuildInputs = [
      python
      pkgs.nftables
    ];
  }
  ''
    mkdir -p work/tests/actual_pilot work/modules/virtualisation/scripts
    cp ${./actual_pilot/test_bootstrap.py} work/tests/actual_pilot/test_bootstrap.py
    cp ${./actual_pilot/test_preflight.py} work/tests/actual_pilot/test_preflight.py
    cp ${../modules/virtualisation/scripts/actual_pilot_bootstrap.py} work/modules/virtualisation/scripts/actual_pilot_bootstrap.py
    cp ${../modules/virtualisation/scripts/actual_pilot_preflight.py} work/modules/virtualisation/scripts/actual_pilot_preflight.py
    cp ${contract.configFile} config.json
    PYTHONDONTWRITEBYTECODE=1 python -m unittest discover -s work/tests/actual_pilot -v
    LD_PRELOAD="${pkgs.buildPackages.lklWithFirewall.lib}/lib/liblkl-hijack.so" \
      nft --check --file ${contract.firewallRules}
    touch "$out"
  ''
