{ config, lib, pkgs, ... }:
let
  cfg = config.codgician.services.mlx5-sriov;
  types = lib.types;

  # Make script for interface
  interfaceNames = builtins.attrNames cfg;
  mkScriptForInterface = name: ''
    echo ${builtins.toString cfg.${name}.vfNum} > /sys/class/net/${name}/device/mlx5_num_vfs
  '' + (builtins.concatStringsSep "\n" (builtins.map
    (x: ''
      ip link set ${name} vf ${builtins.toString x.fst} mac ${x.snd}
      echo "Up" > /sys/class/net/${name}/device/sriov/${builtins.toString x.fst}/link_state
    '')
    (lib.zipLists (lib.range 0 (cfg.${name}.vfNum - 1)) cfg.${name}.macs)));
  script = pkgs.writeScriptBin "mlx5-sriov"
    (builtins.concatStringsSep "\n" (builtins.map mkScriptForInterface interfaceNames));
in
{
  options.codgician.services.mlx5-sriov = lib.mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        vfNum = lib.mkOption {
          type = types.int;
          default = 0;
          description = "Number of VFs to create.";
        };

        macs = lib.mkOption {
          type = types.listOf types.str;
          example = [ "aa:bb:cc:dd:ee:ff" ];
          default = [ ];
          description = "List of MAC addresses that are assigned to created VFs in order.";
        };
      };
    });
    default = { };
    example = lib.literalExpression ''
      {
        enp65s0f0np0 = {
          vfNum = 2;
          macs = [
            "aa:bb:cc:dd:ee:ff"
            "bb:cc:dd:ee:ff:aa"
          ];
        };
      }
    '';
  };

  config = lib.mkIf (builtins.length (builtins.attrNames cfg) > 0) {
    boot.initrd.availableKernelModules = [ "mlx5_core" ];
    systemd.services.mlx5-sriov = {
      enable = true;
      description = "Create VFs for Mellanox ConnectX-4/5 NICs.";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${script}/bin/${script.name}";
        RemainAfterExit = true;
      };
    };
  };
}
