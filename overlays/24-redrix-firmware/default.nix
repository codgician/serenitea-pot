_:

final: _prev: {
  redrix.max98390-firmware = final.callPackage ./max98390-firmware.nix { };
  redrix.cras-dsp = final.callPackage ./cras-dsp.nix { };
  redrix.chromeos-ucm = final.callPackage ./chromeos-ucm.nix { };
  redrix.check-graphs = final.callPackage ./check-graphs.nix {
    wireplumber = final.unstable.wireplumber;
  };
}
