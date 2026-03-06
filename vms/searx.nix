{ pkgs, ... }:
let
  reg = (import ./vm-registry.nix).searx;
in
{
  imports = [
    ./base.nix
    ../modules/services/searx.nix
    ../modules/security/secrets.nix
    ../modules/core/overlays.nix
    (import ./mkMicrovmConfig.nix (
      reg
      // {
        volumes = [
          {
            mountPoint = "/var/lib/searx";
            image = "searx-state.img";
            size = 10240;
          }
        ];
      }
    ))
  ];

  networking.firewall.allowedTCPPorts = [ reg.port ];

  systemd = {
    tmpfiles.rules = [
      "d /persist/searx 0700 root root -"
    ];

    services.searx-secret-key = {
      description = "Generate SearxNG secret key";
      before = [ "searx.service" ];
      requiredBy = [ "searx.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        install -d -m 0700 /persist/searx
        if [ ! -s /persist/searx/secret_key ]; then
          umask 077
          ${pkgs.openssl}/bin/openssl rand -hex 32 > /persist/searx/secret_key
        fi
      '';
    };
  };

  sys = {
    secrets.searxSecretKeyFile = "/persist/searx/secret_key";

    services.searx = {
      enable = true;
      inherit (reg) port;;
      bind = "0.0.0.0";
      reverseProxy.enable = false;
    };
  };
}
