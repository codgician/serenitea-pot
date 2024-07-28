{ config, pkgs, inputs, ... }:
let
  system = pkgs.system;
in
{
  # Install agenix CLI
  config.environment.systemPackages = [ inputs.agenix.packages.${system}.default ];
}
