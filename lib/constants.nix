# Centralized constants shared across hosts, VMs, and services.
# For secrets use sops-nix; for per-host data use host configs.
{
  tailscale.suffix = "mole-delta.ts.net";

  cloudflare = {
    accountId = "1f65156829c5e18a3648609b381dec9c";
    policyId = "897e5beb-2937-448f-a444-4b51ff7479b0";
  };
}
