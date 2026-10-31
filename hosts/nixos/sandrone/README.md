# ⚙️ Sandrone

Radxa Orion O6 ITX desktop with CIX CP8180.

## CIX packages and kernel

The VPU/NPU drivers and userspace packages come from `nur.repos.codgician`. The NUR `kernel-modules` module registers the drivers in `boot.kernelPackages`, so they follow Sandrone's patched kernel rather than NUR's default-kernel builds.

The host keeps its Linux 6.18 patch selection and board configuration in `kernel/`. The pinned `cix-linux-main` series includes the stable-kernel context refreshes, 64-bit DRM plane masks and PDC syscore adaptation; it no longer replaces the PL011 driver. Do not reapply the superseded local patches when updating the input.

Local patches still fix Linlon include paths, export the helpers needed by modular Sky1 pinctrl/AUDSS drivers, and preserve firmware-owned ACPI power state. Some Sky1 options that the series' reference defconfig enables have no Kconfig default and are set explicitly: without `RESET_SKY1` no USB controller probes, and without `PHY_CIX_USB3` the rear USB3-A controllers defer forever. With it built in they probe in initrd, so a keyboard on any rear USB-A port can unlock LUKS. The rear USB-C controllers are dual-role (`dr_mode = "otg"`), so they also need `USB_CDNSP_GADGET`; their PD controllers (`rts5453`), USB-DP PHYs (`phy_cix_usbdp`) and pin controller stay modules and come up in stage 2. Do not load `phy_cix_usbdp` in initrd without the display driver: it resets the combo PHY that also drives DP01, and when an earlier initrd did that the screen stayed blank from the PHY reset on, although the kernel kept booting. `RESET_GPIO` is disabled because the CIX reset-core backport removes the interface used by Linux 6.18's GPIO reset driver; this host uses ACPI. Revisit that setting when the backport and driver are compatible.

`SKY1_GPT_TIMER` is disabled. CIX's GPT driver registers itself as the tick-broadcast device for the power-down idle states, and its compare programming can miss an event; a single miss stalls every CPU (RCU stalls, then a hard hang). Without it, the kernel's hrtimer broadcast on the per-CPU arch timer takes over and the deep idle states remain usable. Re-enable it only after the driver enforces a safe minimum delta.
