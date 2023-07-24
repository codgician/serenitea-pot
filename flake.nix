{
  description = "codgician's nix fleet";

  inputs = {
      nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
      nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-23.05-darwin";
      home-manager.url = "github:nix-community/home-manager/release-23.05";
      home-manager.inputs.nixpkgs.follows = "nixpkgs";
     
      impermanence.url = "github:nix-community/impermanence";
      nixos-hardware.url = "github:NixOS/nixos-hardware/master";     

      darwin.url = "github:lnl7/nix-darwin";
      darwin.inputs.nixpkgs.follows = "nixpkgs"; 
  };
  
  outputs = inputs @ {
    self, 
    nixpkgs,
    nixpkgs-darwin,
    home-manager,
    impermanence,
    darwin,
    ...
  }: 
  let 
    lib = nixpkgs.lib;
    processConfigurations = lib.mapAttrs (n: v: v n);

    # Common configurations for macOS systems
    darwinSystem = system: extraModules: hostName:
      let
        pkgs = import nixpkgs-darwin {
          inherit system;
          config.allowUnfree = true;
        };
      in
      darwin.lib.darwinSystem {
        inherit system;
        specialArgs = { inherit lib pkgs inputs self darwin; };
        modules = [
          home-manager.darwinModules.home-manager
          {
            nix.useDaemon = true;
            nix.settings.experimental-features = [ "nix-command" "flakes" ];
            networking.hostName = hostName;
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs pkgs; };
          }
        ] ++ extraModules;
      };
  in
  {
    # macOS machines
    darwinConfigurations = processConfigurations {
      "Shijia-Mac" = darwinSystem "aarch64-darwin" [ ./hosts/Shijia-Mac/default.nix ];
    };
  };
}
