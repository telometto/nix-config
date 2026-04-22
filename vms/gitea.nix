{
  config,
  pkgs,
  lib,
  inputs,
  VARS,
  consts,
  ...
}:
let
  reg = (import ./vm-registry.nix).gitea;

  # TEMP: pin gitea to the nixpkgs commit that bumped it to 1.26.0, so we get
  # chunked LFS upload responses (go-gitea/gitea#36380, shipped in v1.26.0).
  # No new flake input; fetchTarball pins an exact rev in-tree.
  # DELETE this block (and the assertion below) once `nix flake update nixpkgs`
  # locks a commit at-or-past 836f421fca0b8e112393a929852cd39d6073a723:
  #   gh api repos/NixOS/nixpkgs/compare/836f421fca0b8e112393a929852cd39d6073a723...<new-rev> --jq '.status'
  #   -> want "ahead" or "identical"
  giteaPinRev = "836f421fca0b8e112393a929852cd39d6073a723";
  giteaPinnedNixpkgs = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/${giteaPinRev}.tar.gz";
    sha256 = "0sw830n4n2cx1hn6aqr9yxdyp34s67raxap6s5ir9v5bkzjd3d7y";
  };
  giteaPinnedPkgs = import giteaPinnedNixpkgs {
    inherit (pkgs) system;
    inherit (config.nixpkgs) config;
  };
in
{
  imports = [
    ./base.nix
    ../modules/services/gitea.nix
    inputs.sops-nix.nixosModules.sops
    (import ./mkMicrovmConfig.nix (
      reg
      // {
        volumes = [
          {
            mountPoint = "/var/lib/gitea";
            image = "gitea-state.img";
            size = 102400;
          }
          {
            mountPoint = "/var/lib/postgresql";
            image = "postgresql-state.img";
            size = 10240;
          }
        ];
      }
    ))
  ];

  nixpkgs.overlays = [ (_: _: { inherit (giteaPinnedPkgs) gitea; }) ];

  assertions = [
    {
      assertion = lib.hasPrefix "1.26" pkgs.gitea.version;
      message = "gitea-pin: expected 1.26.x (1.26.0+) from nixpkgs@${giteaPinRev}, got ${pkgs.gitea.version}. Delete the overlay when unstable catches up.";
    }
  ];

  # SOPS configuration for this MicroVM
  # After first boot, get the VM's age key with:
  #   ssh admin@10.100.0.50 "sudo cat /persist/ssh/ssh_host_ed25519_key" | ssh-to-age
  # Then add it to your .sops.yaml and re-encrypt secrets
  sops = {
    defaultSopsFile = inputs.nix-secrets.secrets.secretsFile;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/persist/ssh/ssh_host_ed25519_key" ];
    useSystemdActivation = true;

    secrets = {
      "gitea/lfs_jwt_secret" = {
        mode = "0440";
        owner = "gitea";
        group = "gitea";
      };
    };
  };

  networking.firewall.allowedTCPPorts = [
    reg.port
    2222
  ];

  systemd.tmpfiles.rules = [
    "d /var/lib/gitea 0700 gitea gitea -"
    "d /var/lib/postgresql 0700 postgres postgres -"
  ];

  sys = {
    secrets.giteaLfsJwtSecretFile = config.sops.secrets."gitea/lfs_jwt_secret".path;

    services.gitea = {
      enable = true;

      inherit (reg) port;
      openFirewall = true;
      stateDir = "/var/lib/gitea";
      repositoryRoot = "/var/lib/gitea/repositories";

      database = {
        type = "postgres";
        createDatabase = true;
      };

      lfs = {
        enable = true;

        allowPureSSH = true;

        s3Backend = {
          enable = false;

          endpoint = "${config.networking.hostName}.${consts.tailscale.suffix}:${toString config.sys.services.seaweedfs.s3.port}";
          bucket = "gitea-lfs";
          accessKeyFile = config.sys.secrets.seaweedfsAccessKeyFile;
          secretAccessKeyFile = config.sys.secrets.seaweedfsSecretAccessKeyFile;
          serveDirect = false;
        };
      };

      disableRegistration = true;

      reverseProxy.enable = false;

      settings = {
        server = {
          ROOT_URL = "https://git.${VARS.domains.public}/";
          START_SSH_SERVER = true;

          SSH_DOMAIN = "ssh-git.${VARS.domains.public}";
          SSH_LISTEN_HOST = "0.0.0.0";
          SSH_LISTEN_PORT = 2222;
        };

        session.COOKIE_SECURE = true;
      };
    };
  };
}
