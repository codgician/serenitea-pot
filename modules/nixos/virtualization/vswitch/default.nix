{
  config,
  lib,
  ...
}:
let
  cfg = config.codgician.virtualization.vswitch;
  types = lib.types;
in
{
  options.codgician.virtualization.vswitch = {
    enable = lib.mkEnableOption "Open vSwitch";

    extraGlobalOptions = lib.mkOption {
      type = with types; listOf str;
      description = "Extra options to pass to `ovs-vsctl set Open_vSwitch .`.";
      default = [ ];
      example = [ "other_config:hw-offload=true" ];
    };

    switches = lib.mkOption {
      type =
        with types;
        attrsOf (submodule {
          options = {
            interfaces = lib.mkOption {
              type = with types; attrsOf (submodule { });
              description = "The physical network interfaces connected by the vSwitch, as attribute names.";
              default = { };
              example = {
                "enp1s0" = { };
              };
            };

            macAddress = lib.mkOption {
              type = with types; nullOr str;
              description = "MAC address of the switch.";
              default = null;
              example = "aa:bb:cc:dd:ee:ff";
            };
          };
        });
      description = "Configuration for each switch managed by Open vSwitch.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Open vSwitch configuration
    virtualisation.vswitch = {
      enable = true;
      resetOnStart = true;
    };

    # Switch configurations
    networking.vswitches = lib.mapAttrs (switchName: switchCfg: {
      interfaces = lib.mapAttrs (name: _: { inherit name; }) switchCfg.interfaces;
      extraOvsctlCmds = lib.optionalString (
        switchCfg.macAddress != null
      ) "set bridge ${switchName} other-config:hwaddr=${switchCfg.macAddress}";
    }) cfg.switches;

    # Apply global options to openvswitch
    systemd.services.ovs-vswitchd.preStart = lib.concatMapStringsSep "\n" (
      option: "ovs-vsctl --no-wait set Open_vSwitch . ${option}"
    ) cfg.extraGlobalOptions;
  };
}
