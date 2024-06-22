{ config, lib, ... }:
let
  cfg = config.codgician.services.wireguard;
  types = lib.types;
  hosts = builtins.map (lib.removeSuffix ".nix") (lib.codgician.getRegularFileNames ./peers);
  hostOptions = builtins.listToAttrs
    (builtins.map (name: { inherit name; value = import ./peers + "/${name}.nix" { inherit config; }; }) hosts);
in
{
  options.codgician.services.wireguard = {
    enable = lib.mkEnableOption "Enable WireGuard.";

    interfaces = lib.mkOption {
      type = types.attrsOf (types.submodule (import ./interface-options.nix { inherit lib; }));
      default = { };
      description = lib.mdDcoc "WireGuard interface configurations.";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.wireguard.interfaces = builtins.mapAttrs
      (name: value: {
        ${name} = {
          inherit (hostOptions.${value.host}) privateKeyFile ips listenPort;
          inherit (value) allowedIPsAsRoutes;

          peers = builtins.listToAttrs
            (builtins.map (name: { inherit name; value = { inherit (hostOptions.${name}) name endpoint publicKey presharedKeyFile; }; }) value.peers);
        };
      })
      cfg.interfaces;
  };
}
