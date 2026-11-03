{
  sonarr = {
    title = "Sonarr";
    port = 8989;
    exporterPort = 9707;
  };
  radarr = {
    title = "Radarr";
    port = 7878;
    exporterPort = 9708;
  };
  lidarr = {
    title = "Lidarr";
    port = 8686;
    exporterPort = 9709;
  };
  readarr = {
    title = "Readarr";
    port = 8787;
    exporterPort = 9710;
  };
  bazarr = {
    title = "Bazarr";
    port = 6767;
    exporterPort = 9711;
    portOption = [ "listenPort" ];
    configSubPath = "config/config.ini";
  };
  prowlarr = {
    title = "Prowlarr";
    port = 9696;
    exporterPort = 9712;
  };
}
