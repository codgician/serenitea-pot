# NixOS Deployment

This breif guide only covers NixOS hosts (excluding LXC containers).

First boot into NixOS Live CD and clone this repository.

## Apply disk layout

This is required for hosts having `disks.nix` file declaring disk partition layout. This is made possible with [disko](https://github.com/nix-community/disko).

If the target host has encrypted partition, please first create key file according to disko configuration.

Navigate to host folder containing `disk.nix` and run following command:

```bash
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./disks.nix
```

After running disko, the newly created partitions should be already mounted at `/mnt`.

## Configure impermanence

For hosts with [impermanence](https://github.com/nix-community/impermanence) enabled, run following command to generate new ssh key pair:

```bash
sudo mkdir -p /mnt/persist/etc/ssh/
sudo ssh-keygen -t ed25519 -f /mnt/persist/etc/ssh/ssh_host_ed25519_key -C ""
```

Add generated public key to `/secrets/pubkeys.nix`, then navigate to `/secrets` and run following command to rekey all credentials:

```bash
agenix -r
```

## Install NixOS

Before installation, please ensure `config.codgician.services.secure-boot.enabled` is set to `false`.

Run following command under repo root path:

```bash
sudo nixos-install --flake .#hostname
```

You can now reboot from Live CD and boot into your newly installed device.

## Enable secure boot

After first boot, you may try enabling Secure Boot back by setting `codgician.services.secure-boot.enable = true` and following [Lanzaboote's Quick Start Guide](https://github.com/nix-community/lanzaboote/blob/master/docs/QUICK_START.md).
