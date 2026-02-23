{ pkgs, ... }:
let
  # Desktop applications
  desktop = [ ];

  # Gaming and emulation
  gaming = [
    # pkgs.retroarch
    pkgs.melonds
  ];

  # System tools (some already in base packages)
  tools = [
    pkgs.p7zip
  ];
in
{
  environment.systemPackages = desktop ++ gaming ++ tools;
}
