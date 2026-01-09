# Library Functions

Custom Nix library extending `nixpkgs.lib` under `lib.codgician` namespace.

## STRUCTURE

```
lib/
├── default.nix        # Entry: extends lib with codgician namespace
├── utils.nix          # mk*System, forAllSystems, overlay helpers
├── reverse-proxy.nix  # Nginx/Authelia service abstractions
├── service.nix        # mkServiceUserGroupLinux
├── io.nix             # File/folder discovery functions
├── secrets.nix        # Agenix path helpers
├── image.nix          # Image conversion derivations
└── consts.nix         # Path constants (rootDir, modulesDir, etc.)
```

## KEY FUNCTIONS

| Function | Purpose |
|----------|---------|
| `mkNixosSystem` | Build NixOS config with all base modules injected |
| `mkDarwinSystem` | Build Darwin config with all base modules injected |
| `mkPkgs` | Create pkgs with overlays + allowUnfree |
| `forAllSystems` | Generate attrs for all supported architectures |
| `getOverlays` | Aggregate all overlays including lazy `pkgs.unstable` |
| `mkServiceReverseProxyOptions` | Standard options for web services (HTTPS, Authelia, LAN-only) |
| `mkServiceReverseProxyConfig` | Generate Nginx vhost from above options |
| `mkServiceUserGroupLinux` | Create system user/group for services |
| `getFolderPaths` / `getNixFilePaths` | Auto-discover modules/overlays |
| `getAgeSecretPathFromName` | Map secret name to .age file path |

## CONVENTIONS

### Adding New Functions
1. Create in appropriate file (or new file if new domain)
2. File must accept `{ lib, nixpkgs, inputs, outputs, ... }`
3. Return attribute set to merge into `lib.codgician`

### Usage Pattern
```nix
# In any module:
{ lib, ... }:
let
  inherit (lib.codgician) mkServiceReverseProxyOptions;
in { ... }
```

## ANTI-PATTERNS

- Don't bypass `mk*System` - it injects required modules (agenix, impermanence, etc.)
- Don't manually construct overlay lists - use `getOverlays`
- Don't hardcode paths - use `consts.nix` values
