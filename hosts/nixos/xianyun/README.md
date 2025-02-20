# 🪽 Xianyun

Tencent Cloud VM running NixOS.

## Deployment

```bash
nix run github:nix-community/nixos-anywhere -- \
  --copy-host-keys \
  --flake .#xianyun \
  root@<ip> -p <port> 
```
