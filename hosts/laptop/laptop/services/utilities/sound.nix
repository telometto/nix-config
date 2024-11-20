{ config, lib, pkgs, ... }:

{
  # Enable sound.
  hardware.pulseaudio.enable = false; # Default: true
  # OR
  services.pipewire = lib.mkIf (!hardware.pulseaudio.enable) {
    enable = true;
    pulse = { enable = true; };
    jack = { enable = false; };

    alsa = {
      enable = true;
      support32Bit = true;
    };
  };
}
