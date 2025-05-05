{
  config,
  lib,
  pkgs,
  ...
}:
let
  impermanenceCfg = config.codgician.system.impermanence;
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
  };

  # Impermenance for Proxmox VE
  environment.persistence.${impermanenceCfg.path}.directories = lib.mkIf impermanenceCfg.enable [
    "/var/lib/pve-cluster"
    "/var/lib/pve-firewall"
    "/var/lib/pve-manager"
  ];

  # swtpm setup
  environment.systemPackages = with pkgs; [ swtpm ];
  systemd.services = {
    pvedaemon.path = with pkgs; [ swtpm ];
    pve-guests.path = with pkgs; [ swtpm ];
  };
  environment.etc."swtpm_setup.conf".text = ''
    # Program invoked for creating certificates
    create_certs_tool= ${pkgs.swtpm}/share/swtpm/swtpm-localca
    create_certs_tool_config = ${pkgs.writeText "swtpm-localca.conf" ''
      statedir = /var/lib/swtpm-localca
      signingkey = /var/lib/swtpm-localca/signkey.pem
      issuercert = /var/lib/swtpm-localca/issuercert.pem
      certserial = /var/lib/swtpm-localca/certserial
    ''}
    create_certs_tool_options = ${pkgs.swtpm}/etc/swtpm-localca.options
    # Comma-separated list (no spaces) of PCR banks to activate by default
    active_pcr_banks = sha256
  '';

  # hookscript snippets
  environment.etc."pve-snippets/snippets/hookscript-guoba.sh".source = lib.getExe (
    pkgs.writeShellApplication {
      name = "hookscript";
      runtimeInputs = with pkgs; [ systemd ];
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

        case "''${phase}" in
          pre-start)  
            echo "''${vmid} is starting, running pre-start hookscripts..."
            systemctl set-property --runtime -- system.slice AllowedCPUs=0-7,16-39,48-63
            systemctl set-property --runtime -- user.slice AllowedCPUs=0-7,16-39,48-63
            systemctl set-property --runtime -- init.scope AllowedCPUs=0-7,16-39,48-63
            ;;
          pre-stop)
            echo "''${vmid} stopped, running post-stop hookscripts..."
            systemctl set-property --runtime -- system.slice AllowedCPUs=0-63
            systemctl set-property --runtime -- user.slice AllowedCPUs=0-63
            systemctl set-property --runtime -- init.scope AllowedCPUs=0-63
            ;;
        esac
      '';
    }
  );
}
