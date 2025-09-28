# telometto.secrets.*: central secrets options
# Define stable, project-owned options to reference secrets throughout modules.
{ lib, ... }: {
  options.telometto.secrets = {
    # Tailscale auth key file path (resolved from SOPS centrally)
    tsKeyFile = lib.mkOption {
      type = lib.types.nullOr
        lib.types.str; # runtime path string (do not coerce into store)
      default = null;
      description = ''
        Path to the Tailscale auth key file. This is resolved from SOPS in core/sops.nix
        so feature modules can consume it without referencing SOPS directly.
      '';
    };

    # Paperless admin password file path (resolved from SOPS centrally)
    paperlessKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str; # runtime path string
      default = null;
      description = ''
        Path to the Paperless-ngx admin password file. Mapped from SOPS in core/sops.nix.
      '';
    };

    # Searx server secret key file path (resolved from SOPS centrally)
    # Note: Keep this as a runtime path string to avoid leaking secrets to the Nix store.
    searxSecretKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str; # runtime path string
      default = null;
      description = ''
        Path to a file containing the Searx secret key. Mapped from SOPS in core/sops.nix.
      '';
    };

    # BorgBackup password file path (resolved from SOPS centrally)
    borgKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str; # runtime path string
      default = null;
      description = ''
        Path to a file containing the Borg repository passphrase. Mapped from SOPS in core/sops.nix.
      '';
    };

    # Optional: Borg repository URL (if you prefer not to hard-code it in host config)
    borgRepo = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Borg repository URL. If null, set per-host under telometto.services.borgbackup.jobs.<name>.repo.
        If provided here, hosts can reference config.telometto.secrets.borgRepo.
      '';
    };
  };
}
