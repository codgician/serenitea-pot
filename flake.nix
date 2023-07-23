{
  description = "codgician's nix fleet";

  inputs = {
      nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-23.05-darwin";
      home-manager.url = "github:nix-community/home-manager/release-23.05";
      home-manager.inputs.nixpkgs.follows = "nixpkgs";
     
      impermanence.url = "github:nix-community/impermanence";
      nixos-hardware.url = "github:NixOS/nixos-hardware/master";     

      darwin.url = "github:lnl7/nix-darwin";
      darwin.inputs.nixpkgs.follows = "nixpkgs"; 
  };
  
  # add the inputs declared above to the argument attribute set
  outputs = inputs @ {
    self, 
    nixpkgs, 
    home-manager,
    impermanence,
    darwin,
    ...
  }: {
    # we want `nix-darwin` and not gnu hello, so the packages stuff can go
    
    darwinConfigurations."Shijia-Mac" = darwin.lib.darwinSystem {
      # you can have multiple darwinConfigurations per flake, one per hostname

      system = "aarch64-darwin";
      modules = [
         home-manager.darwinModules.home-manager
         ./hosts/Shijia-Mac/default.nix
      ];
    }; 
  };
}
