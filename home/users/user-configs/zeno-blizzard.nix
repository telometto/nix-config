# User-specific configuration for admin user on blizzard host
# This file is automatically imported only for the admin user on blizzard
{
  lib,
  config,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    sqlite
    zsh-powerlevel10k
  ];

  hm = {
    programs = {
      fastfetch = {
        enable = true;
        extraModules = [
          {
            "type" = "disk";
            "folders" = "/";
            "key" = "root";
          }
          {
            "type" = "zpool";
            "folders" = "/flash";
            "key" = "flash";
          }
          {
            "type" = "zpool";
            "folders" = "/rpool";
            "key" = "rpool";
          }
          {
            "type" = "zpool";
            "folders" = "/tank";
            "key" = "tank";
          }
        ];
      };

      beets = {
        enable = true;
        # Uses default plugins: fetchart, embedart, convert, scrub, replaygain, lastgenre, chroma, inline
        # To customize: plugins = [ "fetchart" "embedart" "lastfm" "lyrics" ];
        webInterface = {
          enable = true;
          host = "0.0.0.0";
          port = 8337;
        };
      };
    };

    files = {
      enable = true;

      sshConfig = {
        enable = true;

        hosts = {
          "*" = {
            ForwardAgent = "yes";
            AddKeysToAgent = "yes";
            Compression = "yes";
          };

          "github.com" = {
            Hostname = "ssh.github.com";
            Port = "443";
            User = "git";
            IdentityFile = "${config.home.homeDirectory}/.ssh/zeno-blizzard";
          };

          "ssh-git.*" = {
            User = "git";
            ProxyCommand = "${pkgs.cloudflared.out}/bin/cloudflared access ssh --hostname %h";
          };
        };
      };
    };

    services = {
      gpgAgent = {
        enable = true;
        enableSsh = false;
        sshKeys = [ "727A831B39D2FAC421617C2C203BF5C382E3B60A" ];
      };
    };
  };

  services.gnome-keyring = {
    enable = true;
    # components = [ "secrets" "ssh" ];
  };

  programs = {
    zsh.shellAliases = {
      # Kubernetes
      k = "kubectl";
      kap = "kubectl apply -f";
      kdl = "kubectl delete";
      kgt = "kubectl get";
      kex = "kubectl exec -it";
      klo = "kubectl logs";
      kev = "kubectl events";
      kds = "kubectl describe";

      # systemd
      sysstat = "systemctl status";
      systart = "systemctl start";
      systop = "systemctl stop";
      sysrest = "systemctl restart";
      sysenable = "systemctl enable";
      sysdisable = "systemctl disable";
      syslist = "systemctl list-units --type=service";
      sysfail = "systemctl --failed";

      # journalctl
      jctl = "journalctl";
      jctlf = "journalctl -f";
      jctlu = "journalctl -u";
      jctlb = "journalctl -b";
      jctlerr = "journalctl -p err -b";

      # ZFS management
      zList = "zfs list";
      zSnap = "zfs list -t snapshot";
      zpStatus = "zpool status";
      zpList = "zpool list";

      # Docker/Podman (if enabled)
      dps = "podman ps";
      dpsa = "podman ps -a";
      dimg = "podman images";
      dlog = "podman logs";
      dexec = "podman exec -it";

      # System monitoring
      ports = "ss -tulpn";
      listening = "ss -tlnp";
      meminfo = "free -h";
      diskinfo = "df -h";
      topme = "htop --sort-key PERCENT_CPU";
      topmem = "htop --sort-key PERCENT_MEM";

      # Network
      myip = "curl -s ifconfig.me";
      localip = "ip -4 addr show | grep -oP '(?<=inet\\s)\\d+(\\.\\d+){3}'";
      pingCf = "ping 1.1.1.1";

      # File operations
      ll = "eza -la --git --icons";
      lt = "eza -la --git --icons --tree --level=2";
      lsize = "eza -la --git --icons --sort=size";
      ldate = "eza -la --git --icons --sort=modified";

      # Git shortcuts (server side)
      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gl = "git pull";
      gd = "git diff";
      glog = "git log --oneline --graph --decorate";

      # Nix specific
      nGc = "nix-collect-garbage -d";

      # Quick navigation
      "..." = "cd ../..";
      "...." = "cd ../../..";

      # Safety aliases
      rm = "rm -i";
      cp = "cp -i";
      mv = "mv -i";
    };
  };
}
