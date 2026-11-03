let
  hostPath = "/rpool/unenc/media/data";
  guestPath = "/data";
in
{
  inherit hostPath guestPath;
  share = {
    source = hostPath;
    mountPoint = guestPath;
    tag = "media-data";
    proto = "virtiofs";
  };
}
