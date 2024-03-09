# 🌸 Lumine (WIP)

Azure VM (Gen 2) running NixOS, being the reverse proxy to almost every self-hosted service.

To build system disk `.vhd` for uploading, run:

```bash
nix build .#nixosConfigurations.lumine.config.system.build.azureImage
```

To know the output path of built `.vhd` file, run:

```bash
nix eval .#nixosConfigurations.lumine.config.system.build.azureImage.outPath
```
