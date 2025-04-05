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
      (lib.filterAttrs (_: intCfg: intCfg.type == "dpdk" && intCfg.device != null))
      builtins.attrValues
      (builtins.map (intCfg: intCfg.device))
    ];

  # List of dpdk devices
  dpdkDevs = builtins.concatMap getVswitchDpdkDevs (builtins.attrValues cfg.switches);

  # Whether dpdk is needed to be enabled
  enableDpdk = dpdkDevs != [ ];
in
{
  options.codgician.virtualization.vswitch = {
    enable = lib.mkEnableOption "Open vSwitch";

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

                    device = lib.mkOption {
                      type = with types; nullOr str;
                      description = "PCIe device address, only needed for dpdk type.";
                      default = null;
                      example = "0000:01:00.0";
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
        # Add dpdk configurations for each dpdk interface
        ++ (lib.pipe switchCfg.interfaces [
          (lib.filterAttrs (_: intCfg: intCfg.type == "dpdk" && intCfg.device != null))
          (lib.mapAttrs (intName: intCfg: "set Interface ${intName} options:dpdk-devargs=${intCfg.device}"))
          builtins.attrValues
        ])
      );
    }) cfg.switches;

    # Enable dpdk if configured
    environment.systemPackages = lib.mkIf enableDpdk [ pkgs.dpdk ];
    systemd.services = lib.mkIf enableDpdk {
      # Bind correct driver before starting ovs-vswitchd
      ovs-vswitchd = {
        path = with pkgs; [
          dpdk
          which
          pciutils
          iproute2
        ];

        preStart =
          builtins.concatStringsSep "\n" (
            builtins.map (dev: ''
              if lspci -s ${dev} | grep Mellanox; then
                echo "Skip binding vfio-pci driver for Mellanox NICs"
              else
                echo "Binding ${dev} to vfio-pci driver ..."
                dpdk-devbind.py -b vfio-pci ${dev} --force
              fi
            '') dpdkDevs
          )
          + ''
            ovs-vsctl --no-wait set Open_vSwitch . "other_config:dpdk-init=true"
            ovs-vsctl --no-wait set Open_vSwitch . "other_config:vhost-iommu-support=true"
            ovs-vsctl --no-wait set Open_vSwitch . "other_config:dpdk-extra=${
              builtins.concatStringsSep " " (builtins.map (d: "-a ${d}") dpdkDevs)
            }"
          '';
      };
    };
  };
}
