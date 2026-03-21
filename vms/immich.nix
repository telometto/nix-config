{
  inputs,
  ...
}:
let
  reg = (import ./vm-registry.nix).immich;
in
{
  imports = [
    ./base.nix
    ../modules/services/immich.nix
    inputs.sops-nix.nixosModules.sops
    (import ./mkMicrovmConfig.nix (
      reg
      // {
        volumes = [
          {
            mountPoint = "/var/lib/immich";
            image = "immich-state.img";
            size = 1048576;
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

  # SOPS configuration for this MicroVM
  # After first boot, get the VM's age key with:
  #   ssh admin@10.100.0.70 "sudo cat /persist/ssh/ssh_host_ed25519_key" | ssh-to-age
  # Then add it to your .sops.yaml and re-encrypt secrets
  sops = {
    defaultSopsFile = inputs.nix-secrets.secrets.secretsFile;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/persist/ssh/ssh_host_ed25519_key" ];
    useSystemdActivation = true;

    secrets = { };
  };

  networking.firewall.allowedTCPPorts = [ reg.port ];

  systemd.tmpfiles.rules = [
    "d /var/lib/immich 0700 immich immich -"
    "d /var/lib/postgresql 0700 postgres postgres -"
  ];

  sys.services.immich = {
    enable = true;
    host = "0.0.0.0";
    inherit (reg) port;
    openFirewall = true;
  };
}
