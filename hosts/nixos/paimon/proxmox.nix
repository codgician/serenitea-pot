{
  config,
  lib,
  pkgs,
  ...
}:
let
  mkHookScript =
    {
      runtimeInputs ? [ ],
      preStartCmds ? "",
      postStartCmds ? "",
      preStopCmds ? "",
      postStopCmds ? "",
    }:
    lib.getExe (
      pkgs.writeShellApplication {
        name = "hookscript";
        inherit runtimeInputs;
        text = ''
          USAGE="Usage: $0 vmid phase"
          if [ "$#" -ne "2" ]; then
            echo "Expect 2 arguments, got $#"
            echo "$USAGE"
            exit 1
          fi

          echo "GUEST HOOK: $0 $*"
          vmid=$1
          if ! [[ $vmid =~ ^-?[0-9]+$ ]]; then
            echo "Expect vmid to be a number, got $vmid"
            exit 1
          fi
          phase=$2
          case "''${phase}" in
            pre-start|post-start|pre-stop|post-stop) : ;;
            *) echo "Got unknown phase ''${phase}"; exit 1 ;;
          esac

          echo "''${vmid} in phase ''${phase}"
          case "''${phase}" in
            pre-start)  
              ${preStartCmds}
              ;;
            post-start)
              ${postStartCmds}
              ;;
            pre-stop)
              ${preStopCmds}
              ;;
            post-stop)
              ${postStopCmds}
              ;;
          esac
        '';
      }
    );
in
{
  # Enable Proxmox VE
  networking.firewall.allowedTCPPorts = [ 8006 ];
  services.proxmox-ve = {
    enable = true;
    ipAddress = "192.168.0.21";
  };

  # Reverse proxy
  codgician = {
    services.nginx = {
      enable = true;
      openFirewall = true;
      reverseProxies = {
        "pve.codgician.me" = {
          enable = true;
          https = true;
          domains = [ "pve.codgician.me" ];
          locations."/".proxyPass = "https://127.0.0.1:8006";
        };
      };
    };
    acme."pve.codgician.me".postRun = ''
      cp -f cert.pem /etc/pve/local/pveproxy-ssl.pem
      cp -f key.pem /etc/pve/local/pveproxy-ssl.key
      systemctl restart pveproxy.service
    '';

    # Impermanence for Proxmox VE
    system.impermanence.extraItems =
      builtins.map
        (path: {
          type = "directory";
          inherit path;
        })
        [
          "/var/lib/pve-cluster"
          "/var/lib/pve-firewall"
          "/var/lib/pve-manager"
        ];
  };

  # hookscript snippets
  environment.etc = {
    # CPU pinning for gaming VM
    "pve-snippets/snippets/hookscript-guoba.sh".source = mkHookScript {
      runtimeInputs = with pkgs; [ systemd ];
      preStartCmds = ''
        systemctl set-property --runtime -- system.slice AllowedCPUs=0-7,16-39,48-63
        systemctl set-property --runtime -- user.slice AllowedCPUs=0-7,16-39,48-63
        systemctl set-property --runtime -- init.scope AllowedCPUs=0-7,16-39,48-63
      '';
      preStopCmds = ''
        systemctl set-property --runtime -- system.slice AllowedCPUs=0-63
        systemctl set-property --runtime -- user.slice AllowedCPUs=0-63
        systemctl set-property --runtime -- init.scope AllowedCPUs=0-63
      '';
    };
    # Quirk script to prevent flooding offload failure message
    "pve-snippets/snippets/hookscript-tapnet.sh".source = mkHookScript {
      runtimeInputs = [ config.virtualisation.vswitch.package ];
      postStartCmds = ''
        tap_name="tap''${vmid}i0"
        ovs-vsctl set Interface "$tap_name" type=internal
        ovs-vsctl set Interface "$tap_name" type=system
      '';
    };
  };
}
