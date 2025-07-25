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
            echo "ERROR: Expect 2 arguments, got $#"
            echo "$USAGE"
            exit 1
          fi

          echo "GUEST HOOK: $0 $*"
          vmid=$1
          if ! [[ $vmid =~ ^-?[0-9]+$ ]]; then
            echo "ERROR: Expect vmid to be a number, got $vmid"
            exit 1
          fi
          phase=$2
          case "''${phase}" in
            pre-start|post-start|pre-stop|post-stop) : ;;
            *) echo "ERROR: Got unknown phase ''${phase}"; exit 1 ;;
          esac

          # Function for getting qemu parent pid for current vm
          get_qemu_pid () {
            local qemu_parent_pid
            qemu_parent_pid=$(cat /run/qemu-server/"''${vmid}".pid)
            if [[ -z $qemu_parent_pid ]]; then
              echo "ERROR: failed to get QEMU parent PID for vm $vmid"
              exit 1
            fi
            echo "$qemu_parent_pid"
          }

          # Helper funciton for pinning vCPU threads to host threads
          pin_vcpu () {
            local vcpu_id
            vcpu_id=$1
            local host_thread_id
            host_thread_id=$2

            local qemu_parent_pid
            qemu_parent_pid=$(get_qemu_pid)
            local vcpu_task_pid
            vcpu_task_pid=$(grep "^CPU ''${vcpu_id}/KVM\$" /proc/"''${qemu_parent_pid}"/task/*/comm | cut -d '/' -f5)
            if [[ -z $vcpu_task_pid ]]; then
              echo "ERROR: failed to get Task PID for vCPU $vcpu_id"
              return 1
            fi

            echo "Pinning VM $vmid (PPID=$qemu_parent_pid) vCPU $vcpu_id (TPID=$vcpu_task_pid) to host thread(s) $host_thread_id"
            taskset --cpu-list --pid "$host_thread_id" "$vcpu_task_pid"
          }

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
          locations."/".passthru.proxyPass = "https://127.0.0.1:8006";
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
      postStartCmds = ''
        # Manually set CPU affinity for each vCPU thread
        vcpus=(0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15)
        physical_cpus=(8 40 9 41 10 42 11 43 12 44 13 45 14 46 15 47)
        for i in "''${!vcpus[@]}"; do
          vcpu_id="''${vcpus[i]}"
          physical_cpu_id="''${physical_cpus[i]}"
          pin_vcpu "$vcpu_id" "$physical_cpu_id"
        done
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
