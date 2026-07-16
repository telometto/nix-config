# SSH identities available only to zeno on desktop hosts.
{ config, ... }:
let
  homeDirectory = config.home.homeDirectory;
  personalGitHub = {
    HostName = "ssh.github.com";
    Port = 443;
    User = "git";
    IdentitiesOnly = true;
    IdentityFile = "${homeDirectory}/.ssh/github-key";
  };
in
{
  hm.programs.development.git.signingKey = "${homeDirectory}/.ssh/github-key.pub";

  hm.files = {
    enable = true;
    sshAllowedSigners = [
      ''65364211+telometto@users.noreply.github.com namespaces="git" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPkY5zM9mkSM3E6V8S12QpLzdYgYtKMk2TETRhW5pykE''
      ''226052356+amonomega@users.noreply.github.com namespaces="git" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMdEoq7fpm5wfF6GKpOaebHJUccxcPimffler4ohmRsH''
    ];
  };

  programs.ssh.settings = {
    "192.168.*".SetEnv.TERM = "xterm-256color";

    "github.com" = personalGitHub;
    "github-personal" = personalGitHub;

    "github-work" = {
      HostName = "github.com";
      User = "git";
      IdentitiesOnly = true;
      IdentityFile = "${homeDirectory}/.ssh/amonomega";
    };
  };
}
