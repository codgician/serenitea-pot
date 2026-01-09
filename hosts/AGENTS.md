# Hosts

Machine configurations organized by OS type. Auto-discovered by `hosts/default.nix`.

## STRUCTURE

```
hosts/
├── default.nix       # Exports darwinConfigurations + nixosConfigurations
├── darwin/
│   ├── furina/       # aarch64-darwin (M-series Mac)
│   └── raiden-ei/    # x86_64-darwin
└── nixos/
    ├── fischl/       # Bare metal hypervisor
    ├── focalors/     # VM (Parallels Desktop)
    ├── lumine/       # Azure VM (aarch64-linux)
    ├── nahida/       # Linux Container
    ├── paimon/       # Bare metal hypervisor (primary server)
    ├── sandrone/     # Bare metal (CIX 8180)
    ├── wanderer/     # WSL
    └── xianyun/      # Tencent Cloud VM
```

## WHERE TO LOOK

| Task | Location |
|------|----------|
| Add NixOS host | Create `nixos/<name>/default.nix` calling `lib.codgician.mkNixosSystem` |
| Add Darwin host | Create `darwin/<name>/default.nix` calling `lib.codgician.mkDarwinSystem` |
| Hypervisor VMs | `fischl/vms/` or `paimon/vms/` (Libvirt XML) |
| Disk layout | `<host>/disks.nix` (Disko) |
| Hardware quirks | `<host>/hardware.nix` |

## CONVENTIONS

### Required Files
- `default.nix` - Calls `mk*System { hostName, system, modules }`
- `system.nix` - Imported by default.nix

### Optional Files
- `hardware.nix` - Kernel, boot, drivers (NixOS)
- `disks.nix` - Disko partitioning (NixOS)
- `network.nix` - Complex networking (SR-IOV, bridges)
- `brew.nix` - Homebrew packages (Darwin)

### Naming Rules
- **VMs**: Archons/Dragons → immortal, migratable
- **Bare metal**: Human characters → mortal, fixed
- **aarch64**: Fontaine/Descenders (unique origin)
- **WSL/subsystems**: Male characters

## ANTI-PATTERNS

- Don't duplicate module logic here - use `modules/` for reusable config
- Don't hardcode secrets - use `config.age.secrets`
- Check `docs/naming-convention.md` before naming new hosts
