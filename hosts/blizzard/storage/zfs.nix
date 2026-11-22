_: {
  sys.services.zfs.enable = true;

  sys.services.sanoid = {
    enable = true;

    datasets = {
      rpool = {
        useTemplate = [ "production" ];
        recursive = true;
      };

      "rpool/unenc/media" = {
        autosnap = false;
      };

      "rpool/enc/transfers" = {
        useTemplate = [ "production" ];
        autoprune = true;
        monthly = 1;
        weekly = 1;
        daily = 0;
        hourly = 0;
      };

      flash = {
        useTemplate = [ "production" ];
        recursive = true;
      };
    };
  };
}
