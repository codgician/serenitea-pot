# 📸 Charlotte (WIP)

[Lenovo ChromeBook Duet](https://www.lenovo.com/us/en/p/laptops/lenovo/lenovo-edu-chromebooks/lenovo-chromebook-duet-10/zziczctct1x).

Building stage-1 image for kernel upgrade:

```bash
nix build .#nixosConfigurations.charlotte.config.mobile.outputs.depthcharge.kpart
```

Get path to built image:

```bash
nix eval .#nixosConfigurations.charlotte.config.mobile.outputs.depthcharge.kpart.outPath
```

Applying kernel upgrade:

```bash
sudo dd of=/dev/mmcblk0p1 if=<built image path>

```
