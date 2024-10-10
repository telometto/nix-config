# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:

{
  virtualisation = {
  	containers = {
  	  enable = true;

  	  storage = {
  	  	settings = {
  	  	  storage = {
  	  	  	driver = "zfs"; # Sets the storage driver to zfs
  	  	  };
  	  	};
  	  };
  	};

  	podman = {
  		enable = true; # Enables podman
  		dockerCompat = true; # Enables docker compatibility
  		dockerSocket.enable = true; # Enables docker socket
  		autoPrune.enable = true; # Enables auto pruning
  		defaultNetwork.settings.dns_enabled = true; # Enables DNS
  	};

  	oci-containers = {
  		backend = "podman"; # Sets the backend to podman
  	};
  };
}
