{
  listenAddress,
  scannerAddress,
  port,
}:
let
  # Guard local delivery on every interface, before Tailscale's INPUT accept.
  # Do not affect traffic Blizzard forwards as a subnet router.
  ingress = "-m addrtype --dst-type LOCAL -p tcp --dport ${toString port}";
in
{
  extraCommands = ''
    # Keep the listener closed while constructing/reloading its own chain.
    iptables -w -t raw -I PREROUTING 1 ${ingress} -j DROP
    iptables -w -t raw -N SANDFLY_SSH 2>/dev/null || true
    iptables -w -t raw -F SANDFLY_SSH
    iptables -w -t raw -A SANDFLY_SSH -i tailscale0 -s ${scannerAddress}/32 -d ${listenAddress}/32 -j RETURN
    iptables -w -t raw -A SANDFLY_SSH -j DROP
    if ! iptables -w -t raw -C PREROUTING ${ingress} -j SANDFLY_SSH 2>/dev/null; then
      iptables -w -t raw -I PREROUTING 1 ${ingress} -j SANDFLY_SSH
    fi
    if ! ip6tables -w -t raw -C PREROUTING ${ingress} -j DROP 2>/dev/null; then
      ip6tables -w -t raw -I PREROUTING 1 ${ingress} -j DROP
    fi
    while iptables -w -t raw -D PREROUTING ${ingress} -j DROP 2>/dev/null; do :; done
  '';

  extraStopCommands = ''
    # Preserve denial through reload failures and firewall stops. A successful
    # start removes these temporary IPv4 denies after the guard is installed.
    if ! iptables -w -t raw -C PREROUTING ${ingress} -j DROP 2>/dev/null; then
      iptables -w -t raw -I PREROUTING 1 ${ingress} -j DROP
    fi
    if ! ip6tables -w -t raw -C PREROUTING ${ingress} -j DROP 2>/dev/null; then
      ip6tables -w -t raw -I PREROUTING 1 ${ingress} -j DROP
    fi
  '';
}
