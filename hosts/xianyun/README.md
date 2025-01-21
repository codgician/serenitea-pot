# 🪽 Xianyun

Tencent Cloud VM running NixOS, being the reverse proxy to almost every self-hosted service.

This virtual machine has impermenance enabled, and has os and data on separate disks.

## Deployment

```bash
nix run github:nix-community/nixos-anywhere -- \
  --copy-host-keys \
  --flake .#xianyun \
  root@<ip> -p <port> 
```
