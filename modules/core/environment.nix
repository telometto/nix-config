{ lib, ... }:
{
  environment.variables = {
    EDITOR = lib.mkForce "micro";
    SSH_ASKPASS_REQUIRE = lib.mkDefault "prefer";
  };

  programs.zsh.enable = lib.mkDefault true;
}
