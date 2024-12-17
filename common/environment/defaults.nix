/**
 * This Nix expression defines shared environment configuration defaults.
 * It sets up environment variables that are applied globally.
 */

{ config, lib, pkgs, ... }:

{
  environment = {
    variables = {
      # Set the default editor
      EDITOR = "micro";

      # Set the default pager
      # PAGER = "less";

      # Set the SSH_ASKPASS_REQUIRE
      SSH_ASKPASS_REQUIRE = "prefer";

      # Git configuration
      # GIT_SSH_COMMAND = "ssh -i /etc/ssh/ssh_host_ed25519_key";
    };
  };
}
