{
  guestIPv4,
  lib,
  vpsIPv4,
}:
let
  ingress = "-i tailscale0 -m addrtype --dst-type LOCAL -p tcp --dport 8096";
  guestIngress = "-i tailscale0 -d ${guestIPv4}/32 -p tcp --dport 8096";
in
{
  extraCommands = ''
    # Subnet routing can SNAT any tailnet peer to the bridge gateway. Block
    # direct guest access before forwarding, even when the VPS relay is off.
    if ! iptables -w -t raw -C PREROUTING ${guestIngress} -j DROP 2>/dev/null; then
      iptables -w -t raw -I PREROUTING 1 ${guestIngress} -j DROP
    fi

    # This chain is owned entirely by the Jellyfin VPS guard. A temporary
    # PREROUTING DROP keeps it closed while we rebuild it on every reload.
    iptables -w -t raw -I PREROUTING 1 ${ingress} -j DROP
    iptables -w -t raw -N JELLYFIN_VPS 2>/dev/null || true
    if ! ip6tables -w -t raw -C PREROUTING ${ingress} -j DROP 2>/dev/null; then
      ip6tables -w -t raw -I PREROUTING 1 ${ingress} -j DROP
    fi

    # Refuse to erase an unexpected rule, including another peer or logging.
    # Keep Jellyfin blocked without failing the whole NixOS firewall reload.
    # Old reloads may leave more than one DROP but at most one peer RETURN.
    chain_rules=$(iptables -w -t raw -S JELLYFIN_VPS)
    previous_peer_count=0
    unexpected_rule=0
    while IFS= read -r rule; do
      case "$rule" in
        ""|"-N JELLYFIN_VPS"|"-A JELLYFIN_VPS -j DROP") ;;
        "-A JELLYFIN_VPS -s "*"/32 -j RETURN")
          previous_peer_count=$((previous_peer_count + 1))
          ;;
        *)
          echo "Unexpected rule in JELLYFIN_VPS: $rule" >&2
          unexpected_rule=1
          ;;
      esac
    done <<< "$chain_rules"
    if [ "$previous_peer_count" -gt 1 ]; then
      echo "JELLYFIN_VPS has more than one peer rule" >&2
      unexpected_rule=1
    fi

    if [ "$unexpected_rule" -eq 0 ]; then
      iptables -w -t raw -F JELLYFIN_VPS
      iptables -w -t raw -A JELLYFIN_VPS -j DROP
      ${lib.optionalString (vpsIPv4 != null) ''
        iptables -w -t raw -I JELLYFIN_VPS 1 -s ${vpsIPv4}/32 -j RETURN
      ''}
      if ! iptables -w -t raw -C PREROUTING ${ingress} -j JELLYFIN_VPS 2>/dev/null; then
        iptables -w -t raw -I PREROUTING 1 ${ingress} -j JELLYFIN_VPS
      fi
      while iptables -w -t raw -D PREROUTING ${ingress} -j DROP 2>/dev/null; do :; done
    else
      echo "Jellyfin VPS ingress remains blocked; inspect JELLYFIN_VPS" >&2
    fi
  '';

  extraStopCommands = ''
    # A failed firewall reload must leave the raw ingress guard closed.
    if ! iptables -w -t raw -C PREROUTING ${guestIngress} -j DROP 2>/dev/null; then
      iptables -w -t raw -I PREROUTING 1 ${guestIngress} -j DROP
    fi
    iptables -w -t raw -I PREROUTING 1 ${ingress} -j DROP 2>/dev/null || true
  '';
}
