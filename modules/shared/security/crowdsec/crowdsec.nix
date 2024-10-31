{ config, pkgs, lib, inputs, myVars, ... }:

{
  import = [
    inputs.crowdsec.nixosModules.crowdsec
    inputs.crowdsec.nixosModules.crowdsec-firewall-bouncer  
  ];

  nixpkgs.overlays = [ inputs.crowdsec.overlays.default ];

  services.crowdsec = {
    enable = true;

    enrollKeyFile = "/opt/sec/crowdsec-file";

    settings = {
      api.server = {
        listen_url = "127.0.0.1:9998";
      };
    };
  };

  services.crowdsec-firewall-bouncer = {
    enable = true;

    settings = {
      api_key = myVars.general.crowdsecApiKey;
      api_url = "http://localhost:9998";
    };
  };

  systemd.services.crowdsec.serviceConfig = {
    ExecStartPre = let
      script = pkgs.writeScriptBin "register-bouncer" ''
        #!${pkgs.runtimeShell}
        set -eu
        set -o pipefail

        if ! cscli bouncers list | grep -q "my-bouncer"; then
          cscli bouncers add "my-bouncer" --key "${myVars.general.crowdsecApiKey}"
        fi
      '';
    in ["${script}/bin/register-bouncer"];
  };

  environment.systemPackages = with pkgs; [ crowdsec ];
}
