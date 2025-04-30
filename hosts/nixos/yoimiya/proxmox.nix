{ pkgs, ... }: {
  # Enable proxmox VE
  services.proxmox-ve = {
    enable = true;
    ipAddress = "192.168.0.21";
  };

  # Make swtpm globally available
  environment.systemPackages = with pkgs; [ swtpm ];

  # swtpm setup
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
}