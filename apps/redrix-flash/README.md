# Redrix firmware updates

`redrix-flash` updates an existing MrChromebox UEFI installation on Google
Redrix, including subsequent updates of these NUR builds. It uses the
`redrix-ec` and `redrix-coreboot` packages from the locked
NUR input. Firmware is built or downloaded before the app starts.

From this repository:

```sh
sudo nix run .#redrix-flash -- status
sudo nix run .#redrix-flash -- coreboot --backup-dir /home/codgi/firmware-backups --dry-run
sudo nix run .#redrix-flash -- ec-rw --backup-dir /home/codgi/firmware-backups --dry-run
```

A dry run checks prerequisites, reads the device, saves a backup, and prepares
the image without changing firmware, drivers, or pending EC resets. Inspect
its output, then flash with:

```sh
sudo nix run .#redrix-flash -- coreboot --backup-dir /home/codgi/firmware-backups
sudo nix run .#redrix-flash -- ec-rw --backup-dir /home/codgi/firmware-backups
```

Each command asks you to type `FLASH` after preparing the backup. `--yes`
skips that prompt. Keep AC connected. The app blocks sleep and shutdown during
updates. Coreboot takes effect after you reboot. After an EC RW update, save
your work, **shut down normally, then power on again**: the app queues an EC
cold reset for that shutdown. The old EC firmware continues running from RAM
until then. The app never initiates an immediate EC reset or OS shutdown.

## What gets written

- **EC RW:** the upper 256 KiB of the 512 KiB EC flash. The app backs up the
  entire EC, checks the chip and write protection, erases/writes RW, and reads
  back the entire flash. It verifies RW against the packaged image and RO
  against the backup before queuing activation. EC protection stays unchanged.
- **Coreboot:** the BIOS region from the device's Alder Lake flash descriptor.
  The app saves a complete 32 MiB backup and preserves `SMMSTORE` (including
  UEFI variables and enrolled keys), `RO_VPD`, `RW_MRC_CACHE`, and existing
  CBFS HWID, serial number, and VPD. Descriptor and Intel ME contents are
  preserved. Flashrom verifies the written BIOS region.

Coreboot follows [MrChromebox's updater](https://github.com/MrChromebox/scripts/blob/main/functions.sh):
flashrom's `internal` programmer accesses the Intel SPI controller, and
`--ifd -i bios --noverify-all` restricts writing and verification to the BIOS
region from the live Intel flash descriptor. A full-chip read is required for
the backup. Linux must allow this access: disable UEFI Secure Boot and boot
with `iomem=relaxed` if required. The app does not unbind or reload SPI drivers.

For the confirmed write, the app temporarily stops `fwupd.service`. A private
runtime systemd drop-in prevents D-Bus reactivation during flashing. The app
removes that drop-in and restarts the service if it was running, including on
failure. Dry runs leave services untouched. Existing masks are preserved.

The previous MTD implementation could fail with `Module spi_intel_pci is in use` because fwupd holds `/dev/mtd0` open, even after the controller is unbound.
The internal programmer avoids that unload requirement. If flashrom reports
BIOS write protection, follow [MrChromebox's write-protection guidance](https://docs.mrchromebox.tech/docs/firmware/wp/)
before retrying; the app does not clear protection ranges or force writes.
Stock ChromeOS firmware installation and EC RO flashing are outside its scope.

## EC update and activation

Redrix's Nuvoton NPCX9 [loads firmware from flash into SRAM](https://chromium.googlesource.com/chromiumos/platform/ec/+/refs/heads/ec-legacy/chip/npcx/config_flash_layout.h)
and executes it there. The running RW image can therefore keep servicing host commands while
its flash region is rewritten. The app checks for the Redrix chip reported by
`ectool chipinfo` (`Nuvoton`, `NPCX993F`) and the expected flash geometry.
This procedure must not be generalized to ECs that execute directly from flash.

No RO jump, SuzyQ cable, or hardware write-protection change is needed for
this RW update. `wp_gpio_asserted ro_at_boot ro_now` (`0x0b`) is supported.
The system lock blocks RW-to-RO jumps, which explains the earlier app's
`EC did not jump to RO` failure, but does not prevent this RW flash operation.

Only after RW readback and unchanged RO are verified does the app issue
`ectool reboot_ec cold at-shutdown`. It checks `SYSTEM_REBOOT_AT_SHUTDOWN`
(bit 4 of `sysinfo flags`) to confirm the request was stored. Shut down normally
and power on again, then use `redrix-flash status` to check the running version.
An ordinary OS reboot may leave the EC running the old image. A second update
is refused while an EC reboot is already queued.

If the installed BIOS embeds a different EC image, disable **EC Software Sync**
in its settings before updating EC separately; otherwise the BIOS may overwrite
your update at the next boot. The app does not change this setting. The paired
NUR coreboot package embeds the corresponding NUR EC RW image.

## Backups and recovery

Choose a persistent backup directory, such as the home-directory path above.
Every invocation creates a private subdirectory containing the backup, prepared
image, checksums, and session log. No service or persistent system configuration
is installed. Keep another copy of the backup off the device before relying on
it for recovery; firmware backups contain device data and UEFI variables.

If a write or verification fails, keep the device powered and retain the log and
backup. The app stops without activating unverified EC RW or rebooting. It does
not attempt an automatic recovery write. A failed coreboot update may require
an external programmer. After a failed EC write, keep the existing firmware
running in RAM and recover RW before resetting or removing power.

Implementation follows upstream [EC host commands](https://chromium.googlesource.com/chromiumos/platform/ec/+/refs/heads/ec-legacy/util/ectool.cc)
and [MrChromebox's firmware data preservation](https://github.com/MrChromebox/scripts/blob/main/firmware.sh).

Run the simulated EC/coreboot updates and failure-handling checks with:

```sh
nix build .#checks.x86_64-linux.redrix-flash
```
