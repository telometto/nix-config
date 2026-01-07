# OK
{ lib, config, ... }:
let
  cfg = config.sys.services.pipewire;
in
{
  options.sys.services.pipewire.enable = lib.mkEnableOption "PipeWire (disables PulseAudio)";

  config = lib.mkIf cfg.enable {
    security.rtkit.enable = lib.mkDefault true;

    services.pulseaudio.enable = lib.mkForce false;
    # OR
    services.pipewire = {
      enable = lib.mkDefault true;

      pulse.enable = lib.mkDefault true;
      jack.enable = lib.mkDefault false;

      alsa = {
        enable = lib.mkDefault true;
        support32Bit = lib.mkDefault true;
      };
    };
  };
}
