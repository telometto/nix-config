# SSH hardening extension module (non-owner)
# - Contributes to the OpenSSH owner module via extension points
# - Does NOT declare options.telometto.services.openssh.* (owner only)
{ lib, config, ... }: {
  # Harden defaults using the owner's extension points
  telometto.services.openssh.extraSettings = lib.mkOverride 50 {
    PasswordAuthentication = false;
    PermitRootLogin = "no";
    X11Forwarding = false;
    # Add more recommended settings as needed
    # MaxAuthTries = 3;
    # AllowTcpForwarding = "no";
  };

  # Example raw sshd_config additions
  # telometto.services.openssh.extraConfig = ''
  #   MaxSessions 10
  # '';
}
