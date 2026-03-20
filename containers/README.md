## Podman Container Stacks

Declarative Podman container definitions using the
`sys.virtualisation.podman.stacks` module.

### Available Stacks

| Stack | File | Containers | Purpose |
|-------|------|------------|---------|
| lingarr | [lingarr.nix](lingarr.nix) | lingarr, libretranslate, ollama | Automated subtitle translation |
| subgen | [subgen.nix](subgen.nix) | subgen | Whisper-based subtitle generation |

### Architecture

Container stacks run as Podman OCI containers managed by systemd. The
[podman-containers module](../modules/virtualisation/podman-containers.nix)
merges enabled stacks into NixOS's native `virtualisation.oci-containers`
system, giving each container a dedicated systemd service with automatic
restart and boot-time startup.

```
┌─────────────────────────────────────────┐
│  Host (blizzard)                        │
│  └── sys.virtualisation.enable = true   │
│      └── Podman + OCI backend           │
└─────────────────────────────────────────┘
         │
         ├── lingarr stack
         │   ├── lingarr      (:11025)
         │   ├── libretranslate (:11026)
         │   └── ollama       (:11434)
         │
         └── subgen stack
             └── subgen       (:11027)
```

### Key Differences from MicroVMs

| Aspect | MicroVMs | Container Stacks |
|--------|----------|------------------|
| Isolation | Full VM (kernel, network namespace) | Process-level (shared kernel) |
| Config | `vms/*.nix` + registry + mkMicrovmConfig | `containers/*.nix` (self-contained) |
| Management | microvm.nix hypervisor | Podman via systemd |
| Use case | Services needing strong isolation | Upstream images without NixOS modules |

### Creating a New Stack

1. Create `containers/<stack-name>.nix`:

```nix
{ lib, ... }:
{
  config.sys.virtualisation.podman.stacks.<stack-name> = {
    containers = {
      my-app = {
        image = "registry/image:tag";
        ports = [ "8080:80" ];
        volumes = [ "/host/path:/container/path" ];
        environment = {
          SOME_VAR = "value";
        };
      };
    };
  };
}
```

2. Import and enable in the host config
   (e.g., `hosts/<hostname>/virtualisation/containers.nix`):

```nix
{
  imports = [
    ../../../containers/<stack-name>.nix
  ];

  sys.virtualisation.podman.stacks.<stack-name>.enable = true;
}
```

3. Build and switch:

```bash
sudo nixos-rebuild switch --flake .#<hostname>
```

### Container Options

Each container in a stack supports:

- `image` — OCI image to run (required)
- `ports` — Port mappings (`"host:container"` strings)
- `volumes` — Volume mounts (`"src:dst"` strings)
- `environment` — Environment variables (attrset)
- `environmentFiles` — Paths to env files
- `dependsOn` — Other container names to start first
- `extraOptions` — Extra CLI flags for `podman run`
- `labels` — Container labels
- `cmd` — Command arguments
- `entrypoint` — Override image entrypoint
- `user` — Override container user
- `autoStart` — Start on boot (default: `true`)

### Related Documentation

- [System Modules](../modules/README.md) — Module conventions
- [MicroVM Configurations](../vms/README.md) — VM-based alternative
- [Blizzard host](../hosts/blizzard/) — Server running both VMs and containers

______________________________________________________________________

*This documentation was generated with the assistance of LLMs and may require
verification against current implementation.*
