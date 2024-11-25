{ lib, inputs, ... }: rec {
  # Package overlays
  overlays = [ (self: super: { inherit lib; }) ]
    ++ (builtins.map
    (x: import x { inherit inputs lib; })
    (with lib.codgician; getNixFilePaths overlaysDir));

  # Make package universe
  mkPkgs = nixpkgs: system: (import nixpkgs {
    inherit system overlays;
    config.allowUnfree = true;
    flake.source = nixpkgs.outPath;
  });

  # List of supported systems
  darwinSystems = [ "aarch64-darwin" "x86_64-darwin" ];
  linuxSystems = [ "aarch64-linux" "x86_64-linux" ];
  allSystems = darwinSystems ++ linuxSystems;

  # Generate attribution set for specified systems
  forSystems = systems: func: lib.genAttrs systems (system: func (mkPkgs inputs.nixpkgs system));
  forAllSystems = forSystems allSystems;
  forDarwinSystems = forSystems darwinSystems;
  forLinuxSystems = forSystems linuxSystems;
}
