## MicroVM Configurations

Isolated service VMs using [microvm.nix](https://github.com/astro/microvm.nix)
for lightweight virtualization.

### Available VMs

| VM | Module | Purpose |
|----|--------|---------|
| adguard-vm | [adguard.nix](adguard.nix) | AdGuard Home DNS filtering |
| actual-vm | [actual.nix](actual.nix) | Actual Budget management |

### Architecture

MicroVMs provide isolated environments for services that benefit from:

- Minimal attack surface
- Resource isolation
- Independent updates
- Security boundaries

```
┌─────────────────────────────────────────┐
│  Host (blizzard)                        │
│  └── microvm.nixosModules.host          │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│  vms/base.nix (hardened base)           │
│  ├── Hardened kernel                    │
│  ├── Restrictive sysctl                 │
│  └── Minimal services                   │
└─────────────────────────────────────────┘
         │
         ├── adguard-vm
         └── actual-vm
```

### Base Configuration

[base.nix](base.nix) provides a hardened foundation:

- **Hardened kernel** (`linuxPackages_hardened`)
- **Security sysctl settings** — IP spoofing prevention, disabled ICMP redirects
- **Blacklisted modules** — Bluetooth, webcam drivers
- **Restricted SSH** — No root login, key-only authentication
- **Disabled core dumps** — Prevent sensitive data leaks
- **Journal limits** — Constrained log storage

### Key Differences from Hosts

MicroVMs do **not** use `system-loader.nix` to avoid importing host-only
modules:

```nix
# In flake.nix
adguard-vm = nixpkgs.lib.nixosSystem {
  modules = [
    inputs.microvm.nixosModules.microvm
    ./vms/adguard.nix
    inputs.sops-nix.nixosModules.sops
  ];
};
```

### Creating a New VM

1. Create `vms/<service>.nix`:

```nix
{ lib, pkgs, ... }:
{
  imports = [ ./base.nix ];

  microvm = {
    hypervisor = "qemu";
    vcpu = 2;
    mem = 1024;

    interfaces = [{
      type = "tap";
      id = "vm-<service>";
      mac = "02:00:00:00:00:01";
    }];

    shares = [{
      source = "/var/lib/<service>";
      mountPoint = "/data";
      tag = "<service>-data";
      proto = "virtiofs";
    }];
  };

  # Service configuration
  services.<service>.enable = true;
}
```

2. Register in [flake.nix](../flake.nix):

```nix
<service>-vm = nixpkgs.lib.nixosSystem {
  inherit system;
  modules = [
    inputs.microvm.nixosModules.microvm
    ./vms/<service>.nix
  ];
  specialArgs = { inherit inputs system VARS; };
};
```

### Running VMs

On the host with microvm.nixosModules.host enabled:

```bash
# Start a VM
microvm -c <vm-name>

# List running VMs
microvm -l

# Stop a VM
microvm -k <vm-name>
```

### Security Considerations

- VMs run with minimal privileges
- Network access controlled via tap interfaces
- Filesystem shares use virtiofs for performance
- Each VM has isolated secrets via sops-nix

### Related Documentation

- [microvm.nix documentation](https://github.com/astro/microvm.nix)
- [Blizzard host config](../hosts/blizzard/blizzard.nix) — VM host example

______________________________________________________________________

*This documentation was generated with the assistance of LLMs and may require
verification against current implementation.*
