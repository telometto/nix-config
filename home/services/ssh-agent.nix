{ lib, config, ... }:
let cfg = config.hm.services.sshAgent;
in {
  options.hm.services.sshAgent = {
    enable = lib.mkEnableOption "SSH agent service";
  };

  config = lib.mkIf cfg.enable { services.ssh-agent = { enable = true; }; };
}
