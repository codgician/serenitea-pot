_:

final: _prev: {
  redrix.max98390-firmware = final.callPackage ./max98390-firmware.nix { };
  redrix.cras-dsp = final.callPackage ./cras-dsp.nix { };
  redrix.sof-firmware = final.callPackage ./sof-firmware.nix { };
  redrix.chromeos-ucm = final.callPackage ./chromeos-ucm.nix { };
  redrix.check-graphs = final.callPackage ./check-graphs.nix {
    pipewire = final.redrix.pipewire;
  };
  # Explicit device DSP must fail with the node, never silently become dry audio.
  redrix.pipewire = final.pipewire.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./pipewire-required-graph.patch
      ./pipewire-graph-lifecycle.patch
      ./pipewire-graph-volume.patch
    ];
  });
}
