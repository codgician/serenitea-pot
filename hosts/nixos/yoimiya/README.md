# 🎇 Yoimiya (WIP, untested)

> Just like fireworks!

NixOS configuration for Proxmox VE hypervisor host. 

Migration planned early 2025. So far this profile is work in progress and untested.

## To-dos

Goal: apply on bare-metal early 2025

- [x] init zroot RAID-1 layout
- [ ] evaluate feasibility of installing mlnx-ofed drivers
- [x] migrate existing hacks and services
- [x] add config for proxmox-nixos
- [x] fix missing ovmf firmware in upstream (PR in review)
- [x] fix broken zfs / btrfs management in upstream (PR in review)
- [ ] add updater scripts for packages that doesn't have one in upstream
- [ ] migrate secrets
- [ ] (early 2025) switch over.
