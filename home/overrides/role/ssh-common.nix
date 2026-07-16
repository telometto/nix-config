{
  lib,
  config,
  ...
}:
{
  programs.ssh = {
    enable = lib.mkDefault true;
    enableDefaultConfig = false;

    settings = {
      "*" = {
        AddKeysToAgent = lib.mkDefault "no";
        Compression = lib.mkDefault false;
        ControlMaster = lib.mkDefault "no";
        ControlPath = lib.mkDefault "~/.ssh/master-%r@%n:%p";
        ControlPersist = lib.mkDefault "no";
        ForwardAgent = lib.mkDefault false;
        HashKnownHosts = lib.mkDefault true;
        ServerAliveCountMax = lib.mkDefault 3;
        ServerAliveInterval = lib.mkDefault 0;
        StrictHostKeyChecking = lib.mkDefault "ask";
        UserKnownHostsFile = lib.mkDefault "~/.ssh/known_hosts";
      };
      "192.168.*" = {
        IdentitiesOnly = lib.mkDefault true;
        IdentityFile = lib.mkDefault "${config.home.homeDirectory}/.ssh/id_ed25519";
      };
    };
  };
}
