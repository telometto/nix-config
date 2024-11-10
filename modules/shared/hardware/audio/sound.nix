{ config, lib, pkgs, myVars, ... }:

{
  security.rtkit.enable = true;

  # Enable sound.
  hardware.pulseaudio.enable = false; # Default: true
  # OR
  services.pipewire = {
    enable = true;
    pulse = { enable = true; };
    jack = { enable = false; };

    alsa = {
      enable = true;
      support32Bit = true;
    };
  };
}
