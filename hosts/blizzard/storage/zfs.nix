{ ... }:
{
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
    };
  };
}
