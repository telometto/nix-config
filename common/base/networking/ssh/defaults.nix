/**
 * This NixOS module configures the OpenSSH service with specific settings.
 * It enables the OpenSSH service, sets various security and usability options,
 * and opens the firewall for SSH connections.
 *
 * - `services.openssh.enable`: Enables the OpenSSH service.
 * - `services.openssh.banner`: Sets a custom banner for SSH connections.
 * - `services.openssh.settings`: Configures OpenSSH settings:
 *   - `X11Forwarding`: Disallows X11 forwarding (set to false).
 *   - `PermitRootLogin`: Disallows root login via SSH (set to "no").
 *   - `PasswordAuthentication`: Disables password authentication (set to false).
 *   - `UsePAM`: Enables Pluggable Authentication Modules (set to true).
 * - `services.openssh.openFirewall`: Opens the firewall for SSH connections.
 *
 * - `programs.ssh.startAgent`: Starts the SSH agent.
 * - `programs.ssh.enableAskPassword`: Enables asking for passwords.
 * - `programs.ssh.forwardX11`: Disables X11 forwarding.
 * - `programs.ssh.setXAuthLocation`: Disables setting the XAuth location.
 * - `programs.ssh.extraConfig`: Additional SSH client configuration.
 *
 * - `environment.systemPackages`: Installs the OpenSSH package.
 */

{ config, lib, pkgs, ... }:

{
  services.openssh = {
    enable = true;

    banner = ''
               _nnnn_
              dGGGGMMb
             @p~qp~~qMb
             M|@||@) M|
             @,----.JM|
            JS^\__/  qKL
           dZP        qKRb
          dZP          qKKb
         fZP            SMMb
         HZM            MMMM
         FqM            MMMM
       __| ".        |\dS"qML
       |    `.       | `' \Zq
      _)      \.___.,|     .'
      \____   )MMMMMP|   .'
           `-'       `--'
      :: Welcome back to The Matrix! ::
      :: Unauthorized access is prohibited ::
      
    '';

    settings = {
      X11Forwarding = false;
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      UsePAM = true;
    };

    # extraConfig = ''X11UseLocalhost no'';

    openFirewall = true;
  };

  programs = {
    ssh = {
      startAgent = true;
      enableAskPassword = true;
      forwardX11 = false;
      setXAuthLocation = false;

      extraConfig = ''
        Host *
          ForwardAgent yes
          AddKeysToAgent yes
          Compression yes
          ServerAliveInterval 0
          ServerAliveCountMax 3
          HashKnownHosts no
          UserKnownHostsFile ~/.ssh/known_hosts
          ControlMaster no
          ControlPath ~/.ssh/master-%r@%n:%p
          ControlPersist no
      '';
    };
  };

  environment.systemPackages = with pkgs; [
    openssh
    # xorg.xauth
  ];
}
