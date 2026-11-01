# NixOS Recovery

The installer ISO doubles as a rescue system. It contains no secrets. A host's disks are unlocked with their passphrase, and that host's SSH key then decrypts the secrets shared by every host (agent credentials, GitHub tokens) into RAM.

## Boot

```bash
nix build .#installer-iso      # or .#installer-iso-gui
```

Write `result/iso/*.iso` to a USB drive. Hosts using Secure Boot must disable it in firmware to boot the ISO. Re-enable it before booting the host again, or its TPM unlock falls back to a passphrase prompt.

The ISO logs in as `codgi` and accepts codgi's SSH keys, so headless hosts can be reached with `ssh codgi@<address>`.

## Unlock a host

```bash
rescue unlock paimon    # read-only
rescue status
rescue lock
```

`rescue unlock` follows the host's own configuration: it imports pools under the host's `networking.hostId`, prompts for disk passphrases, mounts its file systems at `/mnt`, and binds its impermanence directories in place. It then checks the host key against `secrets/pubkeys.nix` and decrypts the shared secrets to `/run/secrets`. Before that, nothing is decrypted.

Read-only mounts never replay journals; the root gets a RAM overlay for mount points and scratch files. `rescue unlock --rw <host>` asks for the passphrase again, after which `nixos-enter --root /mnt` and `nixos-install --root /mnt` work as usual for hosts of the ISO's architecture. If the host key does not match the host, read-write is refused and the unlock rolled back; read-only still mounts, without secrets.

`rescue lock` wipes decrypted secrets, unmounts everything, exports pools, closes LUKS devices, and restores the ISO's host ID.

### Disks moved to another machine

Boot the receiving machine (or a VM with the disk passed through) from the ISO. Every host with its own disks is known regardless of architecture. Pool names and partition labels repeat across hosts (`zroot`, `disk-main-esp`, …), so `rescue unlock` picks the pool whose label carries the host's host ID or name, prefers partitions on disks it has already attributed to the host, and asks when that does not settle it.

## Diagnose and back up

`omp` is configured as on the hosts and knows it runs on the rescue ISO. Its dendro profile works once a host is unlocked; before that, use `omp login` or `omp --profile github-copilot`.

Persistent state lives under the path `rescue status` reports as `Persist`. Copy it with standard tools, e.g. `sudo rsync -aHAXS --numeric-ids /mnt/persist/ /media/backup/paimon/`, or send an existing ZFS snapshot raw with `zfs send -w`, which keeps it encrypted.

## Maintenance

The ISO deploys only secrets granted to every host with its own disks (`codgician.secrets.hosts`), so any host's key unlocks them all. A new bare-metal or VM host must therefore receive codgi's shared secrets, or the ISO fails to evaluate. The rescue flow is covered by `nix build .#checks.x86_64-linux.rescue`.
