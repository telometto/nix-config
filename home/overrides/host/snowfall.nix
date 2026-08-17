# Host-specific user overrides for snowfall
_: {
  # Snowfall-specific user configuration
  # These settings will be applied to all users on this host
  # nixos-anywhere temporarily relaxes IdentitiesOnly while uploading its
  # install key. Keep the local agent from offering every loaded identity to
  # Avalanche, which can otherwise hit sshd's MaxAuthTries limit.
  programs.ssh.settings."192.168.3.143".IdentityAgent = "none";

  hm = {
    programs = {
      gaming.lutris.enable = true;
    };
  };
}
