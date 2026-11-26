{
  lib,
  serverIPv4,
  tailscaleClients,
  paperless ? null,
  auxiliaryPorts,
}:
let
  ingress = "-m addrtype --dst-type LOCAL -p tcp --dport 2049";
  transition = "${ingress} -m comment --comment nfs-transition -j DROP";
  tcpHelpers = lib.concatStringsSep "," (map toString auxiliaryPorts);
  udpPorts = lib.concatStringsSep "," (map toString ([ 2049 ] ++ auxiliaryPorts));
in
{
  extraCommands = ''
    # Tailscale accepts INPUT before nixos-fw. Protect local NFS in raw
    # PREROUTING and keep a temporary deny through every chain replacement.
    for firewall in iptables ip6tables; do
      if ! "$firewall" -w -t raw -C PREROUTING ${transition} 2>/dev/null; then
        "$firewall" -w -t raw -I PREROUTING 1 ${transition}
      fi
    done
    iptables-restore -w --noflush <<'EOF'
    *raw
    :NFS_ACCESS - [0:0]
    -F NFS_ACCESS
    ${lib.concatMapStringsSep "\n" (client: ''
      -A NFS_ACCESS -i tailscale0 -s ${client}/32 -d ${serverIPv4}/32 -j RETURN
    '') tailscaleClients}
    ${lib.optionalString (paperless != null) ''
      -A NFS_ACCESS -i ${paperless.bridge} -s ${paperless.ip}/32 -d ${paperless.gateway}/32 -j RETURN
    ''}
    -A NFS_ACCESS -j DROP
    COMMIT
    EOF
    ip6tables-restore -w --noflush <<'EOF'
    *raw
    :NFS_ACCESS - [0:0]
    -F NFS_ACCESS
    -A NFS_ACCESS -j DROP
    COMMIT
    EOF
    for firewall in iptables ip6tables; do
      # NFSv2/v3 and UDP are unavailable, including through Tailscale's accept.
      for rule in \
        "-p tcp -m multiport --dports ${tcpHelpers}" \
        "-p udp -m multiport --dports ${udpPorts}"; do
        if ! "$firewall" -w -t raw -C PREROUTING -m addrtype --dst-type LOCAL $rule -j DROP 2>/dev/null; then
          "$firewall" -w -t raw -I PREROUTING 1 -m addrtype --dst-type LOCAL $rule -j DROP
        fi
      done
      if ! "$firewall" -w -t raw -C PREROUTING ${ingress} -j NFS_ACCESS 2>/dev/null; then
        "$firewall" -w -t raw -I PREROUTING 1 ${ingress} -j NFS_ACCESS
      fi
      while "$firewall" -w -t raw -D PREROUTING ${transition} 2>/dev/null; do :; done
    done
    ${lib.concatMapStringsSep "\n" (client: ''
      iptables -w -A nixos-fw -i tailscale0 -s ${client}/32 -d ${serverIPv4}/32 -p tcp --dport 2049 -j nixos-fw-accept
    '') tailscaleClients}
  '';

  extraStopCommands = ''
    # Failed reloads and firewall stops leave NFS closed to new connections.
    for firewall in iptables ip6tables; do
      if ! "$firewall" -w -t raw -C PREROUTING ${transition} 2>/dev/null; then
        "$firewall" -w -t raw -I PREROUTING 1 ${transition}
      fi
    done
  '';
}
