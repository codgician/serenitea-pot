# 🌟 Paimon

NixOS LXC container running in Proxmox VE on my home lab, providing some of the most fundamental services.

To build proxmox LXC tarball, run:

```bash
nix build .#nixosConfigurations.paimon.config.formats.proxmox-lxc
```
