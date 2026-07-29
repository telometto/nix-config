# Sandfly Target Operations

The `sys.security.sandflyTarget` module prepares a host for agentless Sandfly
scans over Tailscale SSH. The account has unrestricted passwordless `sudo`, so
any identity allowed to log in as `sandfly` is effectively root.

The module is intentionally disabled on all hosts until the tailnet policy has
been narrowed and verified.

## Policy prerequisite

Do not enable the module with an SSH rule that grants
`autogroup:nonroot` access to the target. A more specific Sandfly rule does not
cancel a broader rule.

Use dedicated tags so the scanner and targets no longer match the normal
owner-to-self rule. Adapt the administrator login name if it is not `zeno`:

```json
{
  "tagOwners": {
    "tag:sandfly-scanner": ["autogroup:owner"],
    "tag:sandfly-target": ["autogroup:owner"]
  },

  "grants": [
    {
      "src": ["tag:sandfly-scanner"],
      "dst": ["tag:sandfly-target"],
      "ip": ["tcp:22"]
    }
  ],

  "ssh": [
    {
      "action": "accept",
      "src": ["tag:sandfly-scanner"],
      "dst": ["tag:sandfly-target"],
      "users": ["sandfly"]
    },
    {
      "action": "check",
      "src": ["autogroup:owner"],
      "dst": ["tag:sandfly-target"],
      "users": ["zeno"]
    }
  ],

  "tests": [
    {
      "src": "tag:sandfly-scanner",
      "accept": ["tag:sandfly-target:22"]
    }
  ],

  "sshTests": [
    {
      "src": "tag:sandfly-scanner",
      "dst": ["tag:sandfly-target"],
      "accept": ["sandfly"],
      "deny": ["root", "zeno"]
    },
    {
      "src": "snowfall",
      "dst": ["tag:sandfly-target"],
      "check": ["zeno"],
      "deny": ["sandfly", "root"]
    }
  ]
}
```

This is a replacement for the broad owner-to-self
`users = [ "autogroup:nonroot" ]` SSH rule on Sandfly targets. Tailscale grants
are additive; retaining that broad access would preserve the privilege path.
Merge these entries with the other unrelated grants and tests in the policy.

Apply `tag:sandfly-scanner` to the node running the scanner and
`tag:sandfly-target` to each target in the Tailscale admin console. Confirm that
the policy editor accepts all network and SSH tests before rebuilding a target.
Tagged devices are no longer user-owned, so retain the exact administrator SSH
rule shown above if interactive access is required.

## Enable a target

Only after the policy prerequisite is complete:

```nix
sys.security.sandflyTarget = {
  enable = true;
  tailscalePolicyReady = true;
};
```

The confirmation option is deliberately separate because Nix cannot inspect
the external tailnet policy. Enabling the module:

- creates a locked `sandfly` account with no regular SSH keys;
- reconciles Tailscale SSH using `tailscale set --ssh`;
- grants that account unrestricted passwordless `sudo`;
- creates `/usr/local/bin/sudo` as a compatibility link to the NixOS sudo
  wrapper, refusing to overwrite an unrelated path.

Register the target in Sandfly by its Tailscale `100.x` address. Containerized
scanner deployments might not resolve tailnet MagicDNS names.

## Verification

Before the first scan:

1. From the scanner node, connect as `sandfly` and confirm non-interactive
   `sudo` succeeds.
1. From an ordinary owner device, confirm that `sandfly` and `root` are denied.
1. Confirm the normal administrator login still uses the intended `check`
   policy.
1. Run one Sandfly scan and verify it can inspect root-only paths.

## Rollback

Set `sys.security.sandflyTarget.enable = false` and rebuild the target. The
account and sudo rule disappear, and activation removes the compatibility link
only when it still points to the NixOS sudo wrapper. Remove the
`tag:sandfly-target` assignment only after deciding what replacement SSH policy
should govern the host.
