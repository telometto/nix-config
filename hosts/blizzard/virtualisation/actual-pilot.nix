{ ... }:
{
  # Additive private pilot. Production MicroVMs and host ingress stay configured.
  sys.virtualisation.actualPilot = {
    enable = true;
    nodeIP = "192.168.2.100";
  };
}
