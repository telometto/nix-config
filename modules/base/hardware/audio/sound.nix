/**
 * This NixOS module configures audio settings for the system.
 * It enables real-time scheduling for audio processes using `rtkit`,
 * and provides options to enable either PulseAudio or PipeWire for sound management.
 *
 * NOTE: If you enable PipeWire, you must disable PulseAudio.
 *
 * - `security.rtkit.enable`: Enables real-time scheduling for audio processes.
 * - `hardware.pulseaudio.enable`: Disables PulseAudio (default is true).
 * - `services.pipewire`: Configuration for PipeWire, an alternative to PulseAudio.
 *   - `enable`: Enables PipeWire.
 *   - `pulse.enable`: Enables PulseAudio compatibility in PipeWire.
 *   - `jack.enable`: Disables JACK compatibility in PipeWire.
 *   - `alsa`: Configuration for ALSA (Advanced Linux Sound Architecture).
 *     - `enable`: Enables ALSA support.
 *     - `support32Bit`: Enables 32-bit ALSA support.
 */

{ config, lib, pkgs, ... }:

{
  security.rtkit.enable = true;

  # Enable sound.
  services.pulseaudio.enable = false; # Default: true
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
