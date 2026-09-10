_:

final: _prev: {
  redrix.max98390-firmware = final.callPackage ./max98390-firmware.nix { };
  redrix.cras-dsp = final.callPackage ./cras-dsp.nix { };
  redrix.sof-firmware = final.callPackage ./sof-firmware.nix { };
  redrix.chromeos-ucm = final.callPackage ./chromeos-ucm.nix { };
  redrix.volume-curve = final.callPackage ./volume-curve.nix { };
}
