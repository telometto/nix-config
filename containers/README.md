## Podman Containers (quadlet-nix)

Declarative Podman container definitions using
[quadlet-nix](https://github.com/SEIAROTg/quadlet-nix). Containers in this
directory are **Home Manager modules** designed for rootless operation under a
specific user via `virtualisation.quadlet.containers`.

### Available Containers

| Option | File | Containers | Purpose |
|--------|------|------------|---------|
| services.lingarr.enable | [subtitle-stack.nix](subtitle-stack.nix) | lingarr, libretranslate, ollama | Automated subtitle translation |
| services.subgen.enable | [subtitle-stack.nix](subtitle-stack.nix) | subgen | Whisper-based subtitle generation |

### Architecture

Container modules are imported into a user's Home Manager configuration and
run as rootless Podman Quadlet systemd user services. The host must enable
`virtualisation.quadlet.enable = true` (set automatically by the
`sys.virtualisation.enable` option) and the owning user needs
`linger = true` and `autoSubUidGidRange = true`.

```
┌─────────────────────────────────────────┐
│  Host (blizzard)                        │
│  └── sys.virtualisation.enable = true   │
│      └── Podman + quadlet-nix           │
│                                         │
│  User: zeno (linger, autoSubUidGidRange)│
│  └── Home Manager                       │
│      └── virtualisation.quadlet         │
└─────────────────────────────────────────┘
         │
         ├── lingarr (services.lingarr.enable)
         │   ├── lingarr        (:11025)
         │   ├── libretranslate (:11026)
         │   └── ollama         (:11434)
         │
         └── subgen (services.subgen.enable)
             └── subgen         (:11027)
```

### Key Differences from MicroVMs

| Aspect | MicroVMs | Quadlet Containers |
|--------|----------|--------------------|
| Isolation | Full VM (kernel, network namespace) | Process-level (shared kernel) |
| Config | `vms/*.nix` + registry + mkMicrovmConfig | `containers/*.nix` (HM modules) |
| Management | microvm.nix hypervisor | Podman Quadlet via systemd user services |
| Privilege | Root (hypervisor) | Rootless (user namespace) |
| Use case | Services needing strong isolation | Upstream images without NixOS modules |

### Creating a New Container Module

1. Create `containers/<name>.nix` as a Home Manager module:

```nix
{ lib, config, ... }:
let
  cfg = config.services.<name>;
in
{
  options.services.<name> = {
    enable = lib.mkEnableOption "<name> container";
  };

  config = lib.mkIf cfg.enable {
    virtualisation.quadlet.containers.<name> = {
      autoStart = true;
      containerConfig = {
        image = "registry/image:tag";
        publishPorts = [ "8080:80" ];
        volumes = [ "/host/path:/container/path" ];
        environments = {
          SOME_VAR = "value";
        };
        userns = "keep-id";
      };
    };
  };
}
```

2. Import and enable in the host's container config
   (e.g., `hosts/<hostname>/virtualisation/containers.nix`):

```nix
{ VARS, ... }:
let
  username = VARS.users.zeno.user;
in
{
  users.users.${username} = {
    linger = true;
    autoSubUidGidRange = true;
  };

  home-manager.users.${username} = {
    imports = [ ../../../containers/<name>.nix ];
    services.<name>.enable = true;
  };
}
```

3. Build and switch:

```bash
sudo nixos-rebuild switch --flake .#<hostname>
```

### Container Options (quadlet-nix)

Each container in `virtualisation.quadlet.containers.<name>` supports:

- `containerConfig.image` — OCI image to run
- `containerConfig.publishPorts` — Port mappings (`"host:container"` strings)
- `containerConfig.volumes` — Volume mounts (`"src:dst"` strings)
- `containerConfig.environments` — Environment variables (attrset)
- `containerConfig.environmentFiles` — Paths to env files
- `containerConfig.networks` — Network names (e.g., `[ "host" ]`)
- `containerConfig.userns` — User namespace mode (e.g., `"keep-id"`)
- `containerConfig.podmanArgs` — Extra CLI flags for `podman run`
- `containerConfig.devices` — Device passthrough (e.g., `[ "/dev/dri" ]`)
- `containerConfig.shmSize` — Shared memory size (e.g., `"4g"`)
- `autoStart` — Start on boot (default per quadlet-nix)
- `unitConfig` — Systemd unit config (Requires, After, etc.)
- `serviceConfig` — Systemd service config (Restart, TimeoutStartSec, etc.)

See [quadlet-nix options](https://seiarotg.github.io/quadlet-nix) for the
full reference.

### Related Documentation

- [System Modules](../modules/README.md) — Module conventions
- [MicroVM Configurations](../vms/README.md) — VM-based alternative
- [Blizzard host](../hosts/blizzard/) — Server running both VMs and containers

______________________________________________________________________

*This documentation was generated with the assistance of LLMs and may require
verification against current implementation.*
