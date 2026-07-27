let
  serviceVolumes = [
    {
      name = "immich";
      mountPoint = "/var/lib/immich";
      image = "immich-state.img";
      size = 1048576;
    }
    {
      name = "postgresql";
      mountPoint = "/var/lib/postgresql";
      image = "postgresql-state.img";
      size = 10240;
    }
  ];

  persistVolume = {
    name = "persist";
    mountPoint = "/persist";
    image = "persist.img";
    size = 64;
  };

  toMicrovmVolume = volume: builtins.removeAttrs volume [ "name" ];
in
{
  microvmVolumes = builtins.map toMicrovmVolume serviceVolumes;
  microvmPersistVolume = toMicrovmVolume persistVolume;
  backupVolumes = serviceVolumes ++ [ persistVolume ];
}
