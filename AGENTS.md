# PROJECT KNOWLEDGE BASE

## OVERVIEW

Nix Flake monorepo managing NixOS + macOS (nix-darwin) device profiles. Infrastructure-as-Code with Terranix for cloud resources (Azure, Cloudflare, GCP).

## STRUCTURE

```
serenitea-pot/
├── flake.nix         # Entry point - defines all outputs
├── lib/              # Custom lib.codgician namespace
├── hosts/            # Machine configs, auto-discovered
│   ├── darwin/       # macOS: furina, raiden-ei
│   └── nixos/        # Linux: fischl, focalors, lumine, nahida, paimon, sandrone, wanderer, xianyun
├── modules/          # System-level NixOS/Darwin modules
│   ├── generic/      # Cross-platform (users, nix settings)
│   ├── darwin/       # macOS-specific (brew, system)
│   └── nixos/        # Linux-specific (services, virtualization)
├── hm-modules/       # User-level Home Manager modules (dotfiles, apps)
├── packages/         # Custom derivations + terraform-config/
├── overlays/         # Package overrides (00-* first, 99-* last)
├── secrets/          # Agenix-encrypted .age files
├── apps/             # CLI tools: tfmgr, chkexp, mkimg, mkjwe
└── shells/           # Dev environments: default, cloud, repl
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Add new host | `hosts/{darwin,nixos}/<name>/default.nix` | Auto-discovered; use `lib.codgician.mk{Darwin,Nixos}System` |
| Add NixOS service | `modules/nixos/services/<name>/default.nix` | Must define `options.codgician.services.<name>` |
| Add secret | `secrets/` | Edit `secrets.nix` + `pubkeys.nix`, run `agenix -e <name>.age` |
| Modify user dotfiles | `hm-modules/codgi/` | Split by `generic/`, `darwin/`, `nixos/` |
| Add system module | `modules/{generic,darwin,nixos}/` | For system-level config (not user) |
| Add package overlay | `overlays/XX-name/default.nix` | XX = load order (00 first, 99 last) |
| Add DNS record | `packages/terraform-config/cloudflare/zones/codgician-me/records/` | Terranix |
| Add AI model | `packages/terraform-config/celestia/cognitive/akasha/<model>.nix` | Azure OpenAI |
| Hypervisor VMs | `hosts/nixos/fischl/vms/*.xml` | Libvirt/NixVirt XML |

## HOSTS

Auto-discovered via `lib.codgician.getFolderNames` - just create a folder with `default.nix`.

| Host | Type | Platform | Notes |
|------|------|----------|-------|
| furina | Physical Mac | aarch64-darwin | M-series |
| raiden-ei | Physical Mac | x86_64-darwin | Intel |
| fischl | Bare metal | x86_64-linux | Hypervisor, has `vms/` |
| paimon | Bare metal | x86_64-linux | Primary server |
| sandrone | Bare metal | x86_64-linux | CIX 8180 |
| focalors | VM | x86_64-linux | Parallels Desktop |
| nahida | Container | x86_64-linux | LXC |
| lumine | Cloud VM | aarch64-linux | Azure |
| xianyun | Cloud VM | x86_64-linux | Tencent Cloud |
| wanderer | WSL | x86_64-linux | Windows Subsystem |

### Host File Structure

- `default.nix` - Entry point calling `mk*System { hostName, system, modules }`
- `system.nix` - Core system config (required)
- `hardware.nix` - Boot, drivers, kernel (NixOS)
- `disks.nix` - Disko partitioning (NixOS)
- `network.nix` - Complex networking (SR-IOV, bridges)
- `brew.nix` - Homebrew packages (Darwin)

## LIB.CODGICIAN FUNCTIONS

Custom library at `lib/` extending `nixpkgs.lib`.

### System Builders

| Function | Purpose |
|----------|---------|
| `mkNixosSystem` | Build NixOS config with base modules (agenix, impermanence, disko) |
| `mkDarwinSystem` | Build Darwin config with base modules |
| `mkPkgs` | Create pkgs with overlays + allowUnfree |

### Iterators

| Function | Purpose |
|----------|---------|
| `forAllSystems` | Generate attrs for all architectures |
| `forDarwinSystems` / `forLinuxSystems` | Platform-specific iteration |
| `isDarwinSystem` / `isLinuxSystem` | Check system type |

### Service Helpers

| Function | Purpose |
|----------|---------|
| `mkServiceReverseProxyOptions` | Standard options for web services (HTTPS, Authelia) |
| `mkServiceReverseProxyConfig` | Generate Nginx vhost from options |
| `mkServiceUserGroupLinux` | Create system user/group |

### File Discovery

| Function | Purpose |
|----------|---------|
| `getFolderPaths` / `getFolderNames` | Auto-discover subdirectories |
| `getNixFilePaths` / `getNixFileNames` | Auto-discover .nix files |
| `getAgeSecretPathFromName` | Map secret name to .age path |

### Utilities

| Function | Purpose |
|----------|---------|
| `getOverlays` | Aggregate all overlays + lazy `pkgs.unstable` |
| `concatAttrs` | Merge list of attribute sets |
| `convertImage` | ImageMagick wrapper for image conversion |
| `mkNginxLocationForStaticFile` | Create nginx location for static files |

## CONVENTIONS

### Naming (Genshin Impact theme)

| Type | Rule | Examples |
|------|------|----------|
| VMs/Containers | Archons/Dragons | focalors, nahida |
| Bare metal | Human characters | fischl, paimon, sandrone |
| macOS | Female characters | furina, raiden-ei |
| aarch64 | Fontaine/Descenders | furina, lumine |
| WSL/subsystems | Male characters | wanderer |

### Module Options Pattern

```nix
options.codgician.<category>.<name> = { ... };
# In let block:
cfg = config.codgician.<category>.<name>;
```

### Service Module Template

```nix
options.codgician.services.<name> = {
  enable = lib.mkEnableOption "Service description";
  package = lib.mkPackageOption pkgs "<pkg-name>" { };
  backend = lib.mkOption { type = lib.types.enum ["nixpkgs" "container"]; default = "nixpkgs"; };
  reverseProxy = lib.codgician.mkServiceReverseProxyOptions { serviceName = "<name>"; ... };
};

config = lib.mkMerge [
  (lib.mkIf cfg.enable { ... })
  (lib.codgician.mkServiceReverseProxyConfig { serviceName = "<name>"; inherit cfg; })
];
```

### Secret Registration

```nix
codgician.system.agenix.secrets = lib.genAttrs
  ["secret-name-1" "secret-name-2"]
  (name: { owner = cfg.user; group = cfg.group; mode = "0600"; });
```

### Terranix Resource References

```nix
# Use Nix attribute access instead of Terraform interpolation:
storage_account_id = config.resource.azurerm_storage_account.primogems "id";
```

## ANTI-PATTERNS

- **NEVER** include secrets in ISO builds (`installer-iso*`)
- **NEVER** stop before `git push` - work is NOT complete until pushed
- **NEVER** say "ready to push when you are" - YOU must push
- **NEVER** reference secrets directly - use `config.age.secrets.<name>.path`
- **NEVER** bypass `mk*System` - it injects required modules
- **NEVER** write raw `.tf` files - use Terranix expressions
- Check RAID-1 status on `paimon`/`fischl` if boot warnings appear

## COMMANDS

```bash
# Development
nix develop -c $SHELL          # Enter dev shell
nix develop .#repl             # REPL for inspecting values
nix fmt                        # Format all code (treefmt)

# Building
nix build .#nixosConfigurations.<host>.config.system.build.toplevel
nix build .#darwinConfigurations.<host>.system

# Deploying
sudo nixos-rebuild switch --flake .#<host>   # NixOS local
darwin-rebuild switch --flake .#<host>       # Darwin local
nixos-rebuild switch --flake .#<host> --target-host <host> --use-remote-sudo  # Remote

# Secrets
agenix -e secrets/<name>.age   # Edit/create secret

# Terraform
nix run .#tfmgr -- init        # Initialize
nix run .#tfmgr -- plan        # Preview changes  
nix run .#tfmgr -- apply       # Apply changes
```

## NOTES

- Binary cache: `codgician.cachix.org`
- CI: Garnix (not GitHub Actions for builds)
- `pkgs.unstable.*` available via lazy overlay
- Pass `stable = false` to mk\*System for nixpkgs-unstable
- Impermanence: Register paths with `codgician.system.impermanence.extraItems`
- Terraform auth: Auto-decrypted by `tfmgr` from `secrets/terraform-env.age`
