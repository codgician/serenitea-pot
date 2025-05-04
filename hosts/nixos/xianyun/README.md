# 🪽 Xianyun

Tencent Cloud VM running NixOS.

## Deployment

```bash
nix run github:nix-community/nixos-anywhere -- \
  --copy-host-keys --disko-mode disko \
  --flake .#xianyun \
  root@<ip> -p <port> 
```

If local build is having issues during deployment, consider passing `--build-on-remote`.
