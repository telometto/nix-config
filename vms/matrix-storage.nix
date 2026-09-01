let
  serviceVolumes = [
    {
      name = "matrix-synapse";
      mountPoint = "/var/lib/matrix-synapse";
      image = "matrix-synapse-state.img";
      size = 20480;
    }
    {
      name = "postgresql";
      mountPoint = "/var/lib/postgresql";
      image = "postgresql-state.img";
      size = 102400;
    }
    {
      name = "mas";
      mountPoint = "/var/lib/mas";
      image = "mas-state.img";
      size = 1024;
    }
  ];

  persistVolume = {
    name = "persist";
    mountPoint = "/persist";
    image = "persist.img";
    size = 64;
  };

  bridgeVolume = {
    name = "mautrix-whatsapp";
    mountPoint = "/var/lib/mautrix-whatsapp";
    image = "mautrix-whatsapp-state.img";
    size = 10240;
  };

  optionalBackupVolumes = [ bridgeVolume ];

  toMicrovmVolume = volume: builtins.removeAttrs volume [ "name" ];
in
{
  inherit
    serviceVolumes
    persistVolume
    bridgeVolume
    optionalBackupVolumes
    toMicrovmVolume
    ;
  microvmVolumes = builtins.map toMicrovmVolume serviceVolumes;
  microvmPersistVolume = toMicrovmVolume persistVolume;
  backupVolumes = serviceVolumes ++ [ persistVolume ];
}
