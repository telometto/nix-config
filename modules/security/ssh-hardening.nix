{ lib, ... }:
{
  sys.services.openssh.extraSettings = lib.mkOverride 50 {
    PasswordAuthentication = false;
    PermitRootLogin = "no";
    X11Forwarding = false;
  };
}
