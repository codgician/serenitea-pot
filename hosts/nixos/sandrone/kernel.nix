{ inputs, lib }:
let
  inherit (lib.kernel) yes no;

  patchDir = "${inputs.cix-linux-main}/patches-6.18";

  # The cix-linux-main repo ships its patches as one-per-file under
  # `patches-6.18/`. `builtins.attrNames` (used inside
  # `getRegularFileNames`) already returns names alphabetically sorted,
  # which matches upstream's `0001-…`, `0002-…` ordering.
  cixPatches = map (name: {
    inherit name;
    patch = "${patchDir}/${name}";
  }) (builtins.filter (lib.hasSuffix ".patch") (lib.codgician.getRegularFileNames patchDir));

  # Kconfig settings the CIX patches need but which aren't yet picked up
  # automatically by nixpkgs `common-config.nix` for our profile.
  cixExtraConfig = {
    name = "cix-sky1-extra-config";
    patch = null;
    structuredExtraConfig = {
      USB_CDNS_SUPPORT = yes;
      USB_CDNSP = yes;
      USB_CDNSP_HOST = yes;
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
++ [
  cixExtraConfig
  preemptPin
]
