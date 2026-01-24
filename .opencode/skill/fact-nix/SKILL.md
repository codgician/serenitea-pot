---
name: fact-nix
description: Nix domain knowledge - flake structure, lib.codgician functions, module patterns, hosts reference
---

# Nix Domain Knowledge

## Repository Layout

```
serenitea-pot/
├── flake.nix         # Entry point
├── lib/              # lib.codgician namespace
├── hosts/            # Auto-discovered machine configs
│   ├── darwin/       # macOS: furina, raiden-ei
│   └── nixos/        # Linux: fischl, focalors, lumine, nahida, paimon, sandrone, wanderer, xianyun
├── modules/          # System-level modules
│   ├── generic/      # Cross-platform
│   ├── darwin/       # macOS-specific
│   └── nixos/        # Linux-specific (services here)
├── hm-modules/       # Home Manager modules
├── packages/         # Custom derivations + terraform-config/
├── overlays/         # Package overrides (00-* first, 99-* last)
├── secrets/          # Agenix .age files
├── apps/             # CLI: tfmgr, chkexp, mkimg, mkjwe
└── shells/           # Dev environments
```

## Hosts

| Host | Platform | Type | Notes |
|------|----------|------|-------|
| furina | aarch64-darwin | Physical Mac | Apple Silicon |
| raiden-ei | x86_64-darwin | Physical Mac | Intel |
| paimon | x86_64-linux | Bare metal | Primary server |
| fischl | x86_64-linux | Bare metal | Hypervisor |
| sandrone | x86_64-linux | Bare metal | CIX 8180 |
| lumine | aarch64-linux | Cloud VM | Azure |
| xianyun | x86_64-linux | Cloud VM | Tencent |
| focalors | x86_64-linux | VM | Parallels |
| nahida | x86_64-linux | Container | LXC |
| wanderer | x86_64-linux | WSL | Windows |

## lib.codgician Functions

### System Builders (Always use these)

```nix
# hosts/nixos/<name>/default.nix
{ inputs, ... }:
inputs.self.lib.codgician.mkNixosSystem {
  hostName = builtins.baseNameOf ./.;
}

# hosts/darwin/<name>/default.nix
inputs.self.lib.codgician.mkDarwinSystem {
  hostName = builtins.baseNameOf ./.;
}
```

### Reverse Proxy Helpers

```nix
# In options:
reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
  serviceName = "myservice";
  defaultProxyPass = "http://127.0.0.1:8080";
};

# In config:
config = lib.mkMerge [
  (lib.mkIf cfg.enable { ... })
  (lib.codgician.mkServiceReverseProxyConfig { inherit serviceName cfg; })
];
```

Generated options: `reverseProxy.enable`, `.domains`, `.lanOnly`, `.authelia.enable`, `.proxyPass`

### Other Helpers

| Function | Purpose |
|----------|---------|
| `getFolderPaths/getFolderNames` | Auto-discovery |
| `getAgeSecretPathFromName` | Secret name → path |
| `mkServiceUserGroupLinux` | Create service user/group |

## Module Patterns

### Option Namespace

```nix
options.codgician.<category>.<name> = { ... };
# categories: services, system, users
```

**Use `config.codgician.*` not `config.services.*`**

### Standard Service Module

```nix
{ config, lib, pkgs, ... }:
let
  serviceName = "myservice";
  cfg = config.codgician.services.${serviceName};
in {
  options.codgician.services.${serviceName} = {
    enable = lib.mkEnableOption "My Service";
    user = lib.mkOption { type = lib.types.str; default = serviceName; };
    group = lib.mkOption { type = lib.types.str; default = serviceName; };
    reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
      inherit serviceName;
      defaultProxyPass = "http://127.0.0.1:8080";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      # Wrap existing NixOS service or create systemd service
    })
    (lib.codgician.mkServiceReverseProxyConfig { inherit serviceName cfg; })
  ];
}
```

### Secret Registration

```nix
codgician.system.agenix.secrets = lib.genAttrs
  [ "${serviceName}-env" ]
  (name: { owner = cfg.user; group = cfg.group; mode = "0600"; });

# Use in service:
systemd.services.${serviceName}.serviceConfig.EnvironmentFile = 
  config.age.secrets."${serviceName}-env".path;
```

### Impermanence

```nix
codgician.system.impermanence.extraItems = [
  { type = "directory"; path = cfg.dataDir; inherit (cfg) user group; }
];
```

## Commands

```bash
# Build
nix build .#nixosConfigurations.<host>.config.system.build.toplevel
nix build .#darwinConfigurations.<host>.system

# Deploy (requires approval)
nixos-rebuild switch --flake .#<host> --target-host <host> --use-remote-sudo
darwin-rebuild switch --flake .#<host>

# Test
nixos-rebuild build-vm --flake .#<host>
```
