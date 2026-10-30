{
  inputs,
  lib,
}:
let
  inherit (lib.kernel) yes no;

  # The cix-linux-main repo ships its patches as one-per-file under
  # `patches-6.18/`, refreshed for the current linux-6.18.y. `builtins.attrNames`
  # (used inside `getRegularFileNames`) already returns names alphabetically
  # sorted, which matches upstream's `0001-…`, `0002-…` ordering. Enumerate
  # the original source to avoid import-from-derivation during evaluation.
  patchDir = "${inputs.cix-linux-main}/patches-6.18";
  cixPatches = map (name: {
    inherit name;
    patch = "${patchDir}/${name}";
  }) (builtins.filter (lib.hasSuffix ".patch") (lib.codgician.getRegularFileNames patchDir));

  localPatches = [
    # Build fixes for defects in the downstream CIX patchset.
    {
      name = "cix-kernel-fixes";
      patch = ./kernel-fixes.patch;
    }
    # Preserve firmware-owned ACPI GPIO and regulator state. Without this,
    # stage-2 powers off the mounted root NVMe before its command timeout.
    {
      name = "cix-acpi-power-state";
      patch = ./acpi-power-state.patch;
    }
  ];

  # Kconfig settings the CIX patches need but which aren't yet picked up
  # automatically by nixpkgs `common-config.nix` for our profile.
  cixExtraConfig = {
    name = "cix-sky1-extra-config";
    patch = null;
    structuredExtraConfig = {
      USB_CDNS_SUPPORT = yes;
      USB_CDNSP = yes;
      USB_CDNSP_HOST = yes;
      # The two rear USB3-A controllers share CIXH2034's PHY. Without this
      # provider, the Sky1 wrapper's PHY dependency check defers forever.
      PHY_CIX_USB3 = yes;
      # CIX's 00059 declares this bool without `default ARCH_CIX`. Sky1 USB
      # requires its reset lines; without the provider, every controller
      # defers probe and initrd has no USB keyboard.
      RESET_SKY1 = yes;
      # CIX's 00063 backports the v7.1 reset core, which drops the `of_args`
      # field 6.18's reset-gpio still uses. Sky1 boots via ACPI and has no
      # DT GPIO resets, so leave the driver out instead of patching it.
      RESET_GPIO = no;
      # CIX's 0045 GPT driver becomes the tick-broadcast device for the
      # timer-stopping LPI idle states. Its 64-bit equality comparator is
      # programmed with a one-tick minimum delta that is shorter than the
      # MMIO sequence writing it; one missed compare leaves every CPU polling
      # for a broadcast that never fires, and the machine stalls. The GPT
      # serves no other purpose, so use the arch timer's hrtimer broadcast.
      SKY1_GPT_TIMER = no;
    };
  };

  # Workaround for a nixpkgs kernel-build ambiguity that is unrelated
  # to CIX but bites any patched-kernel + private-cache aarch64 host.
  # See `pkgs/os-specific/linux/kernel/build.nix:353` — its FIXME
  # literally reads "This is stupid and bad." `common-config.nix`
  # declares both
  #   PREEMPT_LAZY      = option yes;
  #   PREEMPT_VOLUNTARY = option yes;
  # to cover every arch+kernel version pair, deferring the Kconfig
  # `choice` resolution to `make oldconfig`. With multiple `=y`
  # candidates in the same `choice` block, oldconfig's pick is
  # non-deterministic across builds (we observed two different
  # configfile outputs for the same source); the multi-output kernel
  # build can then desync its `out` (kernel image) and `dev` (`.config`
  # snapshot), leaving OOT modules built against `-dev` with the wrong
  # vermagic so the running kernel refuses to load them.
  #
  # Force LAZY = y AND the competing members = n so the `choice` has
  # no ambiguity for oldconfig to resolve. Pinning only LAZY is
  # insufficient: oldconfig still sees PREEMPT_VOLUNTARY=y from
  # common-config and may pick it as the choice winner, leaving
  # LAZY=n and triggering "option not set correctly" at config-check
  # time. Remove all three when nixpkgs declares the preempt model
  # unambiguously per-arch.
  preemptPin = {
    name = "preempt-lazy-pin";
    patch = null;
    structuredExtraConfig = {
      PREEMPT_LAZY = lib.mkForce yes;
      PREEMPT_VOLUNTARY = lib.mkForce no;
      PREEMPT = lib.mkForce no;
    };
  };
in
cixPatches
++ localPatches
++ [
  cixExtraConfig
  preemptPin
]
