{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.virtualization.vswitch;
  types = lib.types;
  dpdkDevs = lib.pipe cfg.switches [
    builtins.attrValues
    (builtins.concatMap (switchCfg: switchCfg.interfaces))
    (builtins.filter (intCfg: intCfg.type == "dpdk"))
    (builtins.concatMap (intCfg: intCfg.dev))
    lib.unique
  ];
in
{
  options.codgician.virtualization.vswitch = {
    enable = lib.mkEnableOption "Open vSwitch";
    dpdk.enable = lib.mkEnableOption "Enable DPDK";

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

                    dev = lib.mkOption {
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
    # Add dpdk kmod if enabled
    boot.extraModulePackages = lib.mkIf cfg.dpdk.enable [
      config.boot.kernelPackages.dpdk-kmods
    ];

    # Open vSwitch configuration
    virtualisation.vswitch = {
      enable = true;
      package = with pkgs; if cfg.dpdk.enable then openvswitch-dpdk else openvswitch;
      resetOnStart = true;
    };

    # Switch configurations
    networking.vswitches = lib.mapAttrs (switchName: switchCfg: rec {
      interfaces = lib.mapAttrs (name: intCfg: {
        inherit name;
        inherit (intCfg) type;
      }) switchCfg.interfaces;
      extraOvsctlCmds = lib.concatStringsSep "\n" (
        # Set the MAC address of the switch
        (lib.optional (
          switchCfg.macAddress != null
        ) "set bridge ${switchName} other-config:hwaddr=${switchCfg.macAddress}")
        # Add dpdk configurations for each dpdk interface
        ++ (lib.pipe interfaces [
          (lib.filterAttrs (_: intCfg: intCfg.type == "dpdk"))
          (lib.mapAttrs (
            intName: intCfg: "set Interface ${intName} type=dpdk options:dpdk-devargs=${intCfg.dev}"
          ))
          builtins.attrValues
        ])
      );
    }) cfg.switches;

    # Enable dpdk if configured
    environment.systemPackages = lib.mkIf cfg.dpdk.enable [ pkgs.dpdk ];
    systemd.services = lib.mkIf cfg.dpdk.enable {
      # Bind correct driver before starting ovs-vswitchd
      ovs-vswitchd = {
        path = with pkgs; [
          dpdk
          which
          pciutils
          iproute2
        ];

        preStart = builtins.concatStringsSep "\n" (
          builtins.map (dev: ''
            if lspci -s ${dev} | grep Mellanox; then
              echo "Skip binding vfio-pci driver for Mellanox NICs"
            else
              echo "Binding ${dev} to vfio-pci driver ..."
              dpdk-devbind.py -b vfio-pci ${dev} --force
            fi
          '') dpdkDevs
        );
      };

      ovs-dpdk-setup = {
        description = "Open_vSwitch DPDK setup";
        wantedBy = [ "multi-user.target" ];
        after = [ "ovs-vswitchd.service" ];
        requires = [ "ovs-vswitchd.service" ];

        serviceConfig.Type = "oneshot";
        path = [ config.virtualisation.vswitch.package ];

        script = ''
          ovs-vsctl set Open_vSwitch . "other_config:dpdk-init=true"
          ovs-vsctl set Open_vSwitch . "other_config:vhost-iommu-support=true"
          ovs-vsctl set Open_vSwitch . "other_config:dpdk-extra=${
            builtins.concatStringsSep " " (builtins.map (d: "-a ${d}") dpdkDevs)
          }"
        '';
      };
    };
  };
}
