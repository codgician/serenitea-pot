{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.virtualization.vswitch;
  types = lib.types;

  # Get dpdk devices of a vswitch
  getVswitchDpdkDevs =
    switchCfg:
    lib.pipe switchCfg.interfaces [
      (lib.filterAttrs (_: intCfg: intCfg.type == "dpdk" && intCfg.dpdkDevice != null))
      builtins.attrValues
      (builtins.map (intCfg: intCfg.dpdkDevice))
    ];

  # Make assertion for a dpdk device in a vswitch
  mkVswitchDpdkDevAssertions =
    switchCfg:
    lib.pipe switchCfg.interfaces [
      (lib.filterAttrs (_: intCfg: intCfg.type == "dpdk" && intCfg.dpdkDevice != null))
      (lib.mapAttrs (
        intName: intCfg: {
          assertion = intCfg.extraDpdkDevArgs == [ ] || intCfg.dpdkDevice != null;
          message = "dpdkDevice must be specified if extraDpdkDevArgs is not empty for interface ${intName} of switch ${switchCfg.name}.";
        }
      ))
      builtins.attrValues
    ];

  # List of dpdk devices
  dpdkDevs = builtins.concatMap getVswitchDpdkDevs (builtins.attrValues cfg.switches);

  # Whether dpdk is needed to be enabled
  enableDpdk = dpdkDevs != [ ];
in
{
  options.codgician.virtualization.vswitch = {
    enable = lib.mkEnableOption "Open vSwitch";

    extraGlobalOptions = lib.mkOption {
      type = with types; listOf str;
      description = "Extra options to pass to `ovs-vsctl set Open_vSwitch .`.";
      default = [ ];
      example = [
        "other_config:dpdk-socket-mem=2048"
        "other_config:dpdk-socket-limit=2048"
      ];
    };

    switches = lib.mkOption {
      type =
        with types;
        attrsOf (submodule {
          options = {
            interfaces = lib.mkOption {
              type =
                with types;
                attrsOf (submodule {
                  options = {
                    type = lib.mkOption {
                      type = with types; nullOr str;
                      description = "Type of the interface.";
                      default = null;
                      example = "dpdk";
                    };

                    dpdkDevice = lib.mkOption {
                      type = with types; nullOr str;
                      description = "PCIe device address, only needed for dpdk type.";
                      default = null;
                      example = "0000:01:00.0";
                    };

                    extraDpdkDevArgs = lib.mkOption {
                      type = with types; listOf str;
                      description = ''
                        Extra arguments to pass to `options:dpdk-devargs`, appending after device id.
                        Only effective for dpdk type.
                      '';
                      default = [ ];
                      example = [ "representor=[0]" ];
                    };

                    extraOptions = lib.mkOption {
                      type = with types; listOf str;
                      description = "Extra options to pass to `ovctl set Interface`.";
                      default = [ ];
                      example = [
                        "options:n_rxq=4"
                        "options:rx-steering=rss+lacp"
                      ];
                    };
                  };
                });
              description = "The physical network interfaces connected by the vSwitch.";
              default = { };
              example = {
                "enp1s0" = {
                  type = "internal";
                };
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
      package = with pkgs; if enableDpdk then openvswitch-dpdk else openvswitch;
      resetOnStart = true;
    };

    # Switch configurations
    networking.vswitches = lib.mapAttrs (switchName: switchCfg: {
      interfaces = lib.mapAttrs (name: intCfg: {
        inherit name;
        inherit (intCfg) type;
      }) switchCfg.interfaces;
      extraOvsctlCmds = lib.concatStringsSep "\n" (
        # Set the MAC address of the switch
        (lib.optional (
          switchCfg.macAddress != null
        ) "set bridge ${switchName} other-config:hwaddr=${switchCfg.macAddress}")
        # Set datapath_type to netdev for dpdk
        ++ lib.optional (
          getVswitchDpdkDevs switchCfg != [ ]
        ) "set bridge ${switchName} datapath_type=netdev"
        # Apply extra options for each interface
        ++ (lib.pipe switchCfg.interfaces [
          (lib.mapAttrs (
            intName: intCfg:
            (lib.optional (intCfg.type == "dpdk" && intCfg.dpdkDevice != null)
              "options:dpdk-devargs=${
                builtins.concatStringsSep "," ([ intCfg.dpdkDevice ] ++ intCfg.extraDpdkDevArgs)
              }"
            )
            ++ intCfg.extraOptions
          ))
          (lib.filterAttrs (_: options: options != [ ]))
          (lib.mapAttrsToList (
            intName: options: "set Interface ${intName} ${builtins.concatStringsSep " " options}"
          ))
        ])
      );
    }) cfg.switches;

    # Enable dpdk if configured
    environment.systemPackages = lib.mkIf enableDpdk [ pkgs.dpdk ];
    systemd.services.ovs-vswitchd = {
      path = lib.mkIf enableDpdk (
        with pkgs;
        [
          dpdk
          which
          pciutils
          iproute2
        ]
      );

      preStart = builtins.concatStringsSep "\n" (
        # Bind correct driver before starting ovs-vswitchd
        (lib.optionals enableDpdk (
          builtins.map (dev: ''
            if lspci -s ${dev} | grep Mellanox; then
              echo "Skip binding vfio-pci driver for Mellanox NICs"
            else
              echo "Binding ${dev} to vfio-pci driver ..."
              dpdk-devbind.py -b vfio-pci ${dev} --force
            fi
          '') dpdkDevs
        ))
        # Apply global options to openvswitch
        ++ builtins.map (option: "ovs-vsctl --no-wait set Open_vSwitch . ${option}") (
          (lib.optionals enableDpdk [
            "other_config:dpdk-init=true"
            "other_config:vhost-iommu-support=true"
            "other_config:userspace-tso-enable=true"
            "other_config:dpdk-extra=\"${
              builtins.concatStringsSep " " (builtins.map (d: "-a ${d}") dpdkDevs)
            }\""
          ])
          ++ cfg.extraGlobalOptions
        )
      );
    };

    # Assertions
    assertions = builtins.concatMap mkVswitchDpdkDevAssertions (builtins.attrValues cfg.switches);
  };
}
