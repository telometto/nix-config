{ inputs, pkgs, ... }:
{
  sys.services.rustdeskUnattended = {
    enable = true;
    package =
      inputs.nixpkgs-rustdesk.legacyPackages.${pkgs.stdenv.hostPlatform.system}.rustdesk-flutter-nightly;
  };
}
