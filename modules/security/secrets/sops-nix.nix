{ config, inputs, lib, pkgs, ... }:

{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    defaultSopsFormat = "yaml"; # Default format for sops files

    age = {
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ]; # Paths to the host ssh keys
      keyFile = "/var/lib/sops-nix/key.txt"; # Path to the key file
      generateKey = true; # Generate a new key if the keyFile does not exist
    };

    secrets = {
      serverAdminUser = { };

      desktopAdminUser = { };
      desktopAdminDesc = { };

      laptopAdminUser = { };
      laptopAdminDesc = { };

      tsKeyFilePath = { };
      paperlessKeyFilePath = { };

      borgKeyFilePath = { };
      borgRshFilePath = { };
      borgRepo = { };

      plexDataDir = { };
      testPath = { };
      crowdsecApiKey = { };
      sshPubKey = { };
      gpgSshPubKey = { };
    };
  };

  environment.systemPackages = with pkgs; [
    age
    sops
  ];
}
