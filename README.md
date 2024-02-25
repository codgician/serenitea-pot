# :snowflake: Nix Fleet

[![validate](https://github.com/codgician/nix-fleet/actions/workflows/validate.yml/badge.svg)](https://github.com/codgician/nix-fleet/actions/workflows/validate.yml)
[![evergreen](https://github.com/codgician/nix-fleet/actions/workflows/evergreen.yml/badge.svg)](https://github.com/codgician/nix-fleet/actions/workflows/evergreen.yml)
![Man hours](https://manhours.aiursoft.cn/r/github.com/codgician/nix-fleet.svg)

My fleet of Nix-managed devices.

## Quick start

### Develop

Start developing with your own flavor of shell:

```
nix develop -c $SHELL
```

Don't have nix flake support? Try this instead:

```
nix-shell
```

Format the nix code:

```
nix fmt
```

### Deployment

#### Apply disk layout

This is required for hosts having `disks.nix` file declaring disk partition layout. This is made possible with [disko](https://github.com/nix-community/disko).

Navigate to host folder containing `disk.nix` and run following command:

```bash
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./disks.nix
```

#### Create nix persist folder

After running disko, the newly created partitions should be already mounted at `/mnt`.

For hosts with [impermanence](https://github.com/nix-community/impermanence) enabled, run following command:

```bash
sudo mkdir /mnt/nix/persist
```

#### Generate ssh host keys and rekey credentials

Run following command to generate new ssh key pair:

```bash
sudo mkdir -p /mnt/nix/persist/etc/ssh/
sudo ssh-keygen -t ed25519 -f /mnt/nix/persist/etc/ssh/ssh_host_ed25519_key -C ""
```

Add generated public key to `/secrets/pubKeys.nix`, then navigate to `/secrets` and run following command to rekey all credentials:

```bash
agenix -r
```

#### Install NixOS

Run following command under repo root path:

```bash
sudo nixos-install --flake .#hostname
```
