_:

final: _prev: {
  redrix.max98390-firmware = final.callPackage ./max98390-firmware.nix { };
  redrix.cras-dsp = final.callPackage ./cras-dsp.nix { };
}
