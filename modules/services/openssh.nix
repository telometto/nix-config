{ lib, config, ... }:
let
  cfg = config.sys.services.openssh;

  defaultBanner = builtins.toFile "openssh-banner" ''
    ╔═══════════════════════════════════════════════════════════════════════╗
    ║                                                                       ║
    ║                 ███╗   ██╗██╗██╗  ██╗ ██████╗ ███████╗                ║
    ║                 ████╗  ██║██║╚██╗██╔╝██╔═══██╗██╔════╝                ║
    ║                 ██╔██╗ ██║██║ ╚███╔╝ ██║   ██║███████╗                ║
    ║                 ██║╚██╗██║██║ ██╔██╗ ██║   ██║╚════██║                ║
    ║                 ██║ ╚████║██║██╔╝ ██╗╚██████╔╝███████║                ║
    ║                 ╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝                ║
    ║                                                                       ║
    ║              🔒 Secured by NixOS • Hardened by Design 🔒              ║
    ║                                                                       ║
    ║   ┌─────────────────────────────────────────────────────────────┐     ║
    ║   │  Welcome back to the Matrix!                                │     ║
    ║   │                                                             │     ║
    ║   │    • All connections are monitored and logged               │     ║
    ║   │    • Unauthorized access attempts will be prosecuted        │     ║
    ║   │    • This system is protected by AppArmor MAC               │     ║
    ║   └─────────────────────────────────────────────────────────────┘     ║
    ║                                                                       ║
    ╚═══════════════════════════════════════════════════════════════════════╝
  '';

  defaultSettings = {
    Banner = lib.mkDefault defaultBanner;
    X11Forwarding = lib.mkDefault false;
    PermitRootLogin = lib.mkDefault "no";
    PasswordAuthentication = lib.mkDefault false;
    UsePAM = lib.mkDefault true;
  };
in
{
  options.sys.services.openssh = {
    enable = lib.mkEnableOption "Enable OpenSSH service (owner module)";

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the SSH port in the firewall.";
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Additional OpenSSH settings to be merged with defaults.";
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Additional raw sshd_config lines appended via services.openssh.extraConfig.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.openssh = {
      enable = true;

      inherit (cfg) extraConfig openFirewall;

      settings = lib.mkMerge [
        defaultSettings
        cfg.extraSettings
      ];
    };
  };
}
