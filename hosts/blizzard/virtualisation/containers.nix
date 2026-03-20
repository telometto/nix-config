# Podman container stacks running on blizzard
{ ... }:
{
  imports = [
    ../../../containers/lingarr.nix
    ../../../containers/subgen.nix
  ];

  sys.virtualisation.podman.stacks = {
    lingarr.enable = true;
    subgen.enable = true;
  };
}
