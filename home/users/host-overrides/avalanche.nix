# Host-specific user overrides for avalanche (laptop)
{ config, ... }:
{
  # Avalanche-specific user configuration
  # These settings will be applied to all users on this host

  programs.ssh = {
    enableDefaultConfig = false;
    matchBlocks = {
      "*" = {
        addKeysToAgent = "yes";
        compression = false;
        serverAliveInterval = 0;
        serverAliveCountMax = 3;
        hashKnownHosts = false;
        userKnownHostsFile = "~/.ssh/known_hosts";
        controlMaster = "no";
        controlPath = "~/.ssh/master-%r@%n:%p";
        controlPersist = "no";
      };
      "github.com" = {
        hostname = "ssh.github.com";
        port = 443;
        user = "git";
        identitiesOnly = true;
        identityFile = "${config.home.homeDirectory}/.ssh/github-key";
      };
      "192.168.*" = {
        forwardAgent = true;
        identityFile = "${config.home.homeDirectory}/.ssh/id_ed25519";
        identitiesOnly = true;
      };
    };
  };

  # Laptop-specific overrides:
  # hm.programs.media.extraPackages = with pkgs; [ laptop-specific-media ];
  # programs.git.extraConfig.avalanche = "laptop-setting";
}
