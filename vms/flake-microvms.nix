{
  inputs,
  system,
  VARS,
  ...
}:
let
  nixpkgs = inputs.nixpkgs;
  microvmModule = inputs.microvm.nixosModules.microvm;
  sopsModule = inputs.sops-nix.nixosModules.sops;
  mkMicrovm = modules:
    nixpkgs.lib.nixosSystem {
      inherit system;
      modules = modules;
      specialArgs = { inherit inputs system VARS; };
    };
in
{
  adguard-vm = mkMicrovm [
    microvmModule
    ./adguard.nix
    sopsModule
  ];

  actual-vm = mkMicrovm [
    microvmModule
    ./actual.nix
  ];

  searx-vm = mkMicrovm [
    microvmModule
    ./searx.nix
  ];
}
