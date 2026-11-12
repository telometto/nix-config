{ blizzardIPv4, port }:
let
  ingress = "-m addrtype --dst-type LOCAL -p tcp --dport ${toString port}";
  transition = "${ingress} -m comment --comment immich-ml-transition -j DROP";
in
{
  extraCommands = ''
    # Tailscale accepts packets before nixos-fw. Enforce the source boundary
    # in raw PREROUTING, with atomic chain replacement during reloads.
    iptables-restore --noflush <<'EOF'
    *raw
    :IMMICH_ML - [0:0]
    -F IMMICH_ML
    -A IMMICH_ML -i lo -j RETURN
    -A IMMICH_ML -i tailscale0 -s ${blizzardIPv4}/32 -j RETURN
    -A IMMICH_ML -j DROP
    COMMIT
    EOF
    ip6tables-restore --noflush <<'EOF'
    *raw
    :IMMICH_ML - [0:0]
    -F IMMICH_ML
    -A IMMICH_ML -i lo -j RETURN
    -A IMMICH_ML -j DROP
    COMMIT
    EOF
    for firewall in iptables ip6tables; do
      if ! "$firewall" -w -t raw -C PREROUTING ${ingress} -j IMMICH_ML 2>/dev/null; then
        "$firewall" -w -t raw -I PREROUTING 1 ${ingress} -j IMMICH_ML
      fi
      while "$firewall" -w -t raw -D PREROUTING ${transition} 2>/dev/null; do :; done
    done
    iptables -w -A nixos-fw -i tailscale0 -s ${blizzardIPv4}/32 -p tcp --dport ${toString port} -j nixos-fw-accept
  '';
  extraStopCommands = ''
    # Keep the service closed if a firewall reload fails after its stop phase.
    for firewall in iptables ip6tables; do
      if ! "$firewall" -w -t raw -C PREROUTING ${transition} 2>/dev/null; then
        "$firewall" -w -t raw -I PREROUTING 1 ${transition}
      fi
    done
  '';
}
