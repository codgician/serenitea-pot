# ⚙️ Sandrone

Radxa Orion O6 ITX desktop with CIX CP8180.

## CIX packages and kernel

The VPU/NPU drivers and userspace packages come from `nur.repos.codgician`. The NUR `kernel-modules` module registers the drivers in `boot.kernelPackages`, so they follow Sandrone's patched kernel rather than NUR's default-kernel builds.

The host keeps its Linux 6.18 patch selection and board configuration in `kernel/`. The pinned `cix-linux-main` series includes the stable-kernel context refreshes, 64-bit DRM plane masks and PDC syscore adaptation; it no longer replaces the PL011 driver. Do not reapply the superseded local patches when updating the input.

Local patches still fix Linlon include paths, export the helpers needed by modular Sky1 pinctrl/AUDSS drivers, and preserve firmware-owned ACPI power state. Some Sky1 options that the series' reference defconfig enables have no Kconfig default and are set explicitly: without `RESET_SKY1` no USB controller probes, and without `PHY_CIX_USB3` the rear USB3-A controllers defer forever. With it built in they probe in initrd, so a keyboard on any rear USB-A port can unlock LUKS. The rear Type-C controllers stay unavailable: enabling `USB_CDNSP_GADGET` together with the Type-C PHY/PD modules (`phy_cix_usbdp`, `rts5453`) in initrd stalled boot. `RESET_GPIO` is disabled because the CIX reset-core backport removes the interface used by Linux 6.18's GPIO reset driver; this host uses ACPI. Revisit that setting when the backport and driver are compatible.
