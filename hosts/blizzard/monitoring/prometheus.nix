{ config, lib, ... }:
{
  sys.services.prometheus = {
    enable = true;

    port = 11009;
    listenAddress = "127.0.0.1";
    openFirewall = false;
    scrapeInterval = "5s";

    extraScrapeConfigs = [
      {
        job_name = "traefik";
        static_configs = [
          {
            targets = [ "localhost:8080" ];
          }
        ];
      }
      {
        job_name = "zfs";
        static_configs = [
          {
            targets = [ "localhost:${toString config.sys.services.prometheusExporters.zfs.port}" ];
          }
        ];
      }
      {
        job_name = "kubelet-metrics";
        scheme = "http";
        static_configs = [
          {
            targets = [ "127.0.0.1:10255" ];
          }
        ];
      }
      {
        job_name = "cadvisor-metrics";
        scheme = "http";
        metrics_path = "/metrics/cadvisor";
        static_configs = [
          {
            targets = [ "127.0.0.1:10255" ];
          }
        ];
      }
      {
        job_name = "kube-state-metrics";
        scheme = "http";
        static_configs = [
          {
            targets = [ "127.0.0.1:32080" ];
          }
        ];
      }
      {
        job_name = "electricity-price";
        scrape_interval = "5m";
        static_configs = [
          {
            targets = [ "localhost:${toString config.sys.services.electricityPriceExporter.port}" ];
          }
        ];
      }
      {
        job_name = "arr-exporter";
        static_configs = [
          {
            targets = [ "10.100.0.21:9707" ];
            labels.arr_service = "sonarr";
          }
          {
            targets = [ "10.100.0.22:9708" ];
            labels.arr_service = "radarr";
          }
          {
            targets = [ "10.100.0.26:9709" ];
            labels.arr_service = "lidarr";
          }
          {
            targets = [ "10.100.0.24:9710" ];
            labels.arr_service = "readarr";
          }
          {
            targets = [ "10.100.0.23:9711" ];
            labels.arr_service = "bazarr";
          }
          {
            targets = [ "10.100.0.20:9712" ];
            labels.arr_service = "prowlarr";
          }
        ];
      }
      {
        job_name = "ups";
        metrics_path = "/ups_metrics";
        static_configs = [
          {
            targets = lib.mapAttrsToList (name: _: name) config.sys.services.ups.devices;
          }
        ];
        relabel_configs = [
          {
            source_labels = [ "__address__" ];
            target_label = "__param_target";
          }
          {
            source_labels = [ "__param_target" ];
            target_label = "ups";
          }
          {
            target_label = "__address__";
            replacement = "localhost:${toString config.sys.services.ups.prometheusExporter.port}";
          }
        ];
      }
    ];
  };
}
