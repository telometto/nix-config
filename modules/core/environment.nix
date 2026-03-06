{ lib, ... }:
{
  environment.variables = {
    EDITOR = lib.mkOverride 900 "micro";
    # "prefer" = use graphical askpass when available, fall back to terminal otherwise.
    SSH_ASKPASS_REQUIRE = lib.mkDefault "prefer";
  };

  programs.zsh.enable = lib.mkDefault true;
}
