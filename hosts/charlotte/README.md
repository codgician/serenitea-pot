# 📸 Charlotte (WIP)

[Lenovo ChromeBook Duet](https://www.lenovo.com/us/en/p/laptops/lenovo/lenovo-edu-chromebooks/lenovo-chromebook-duet-10/zziczctct1x), primarily intended as a Home Assistant kiosk.

Building a bootable image:

```bash
nix build .#nixosConfigurations.charlotte.config.mobile.outputs.default
```

Building stage-1 image for kernel upgrade:

```bash
nix build .#nixosConfigurations.charlotte.config.mobile.outputs.depthcharge.kpart
```
