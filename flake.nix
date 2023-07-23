{
  description = "codgician's nix fleet";

  inputs = {
      nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-23.05-darwin";
      home-manager.url = "github:nix-community/home-manager";
      home-manager.inputs.nixpkgs.follows = "nixpkgs";
      
      # nix will normally use the nixpkgs defined in home-managers inputs, we only want one copy of nixpkgs though
      darwin.url = "github:lnl7/nix-darwin";
      darwin.inputs.nixpkgs.follows = "nixpkgs"; 
  };
  
  # add the inputs declared above to the argument attribute set
  outputs = { self, nixpkgs, home-manager, darwin }: {
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
