# Host-specific user overrides for kaizer
# These settings will be applied to all users on kaizer host
{ lib, ... }:
{
  programs.ssh.enableDefaultConfig = false;
}
