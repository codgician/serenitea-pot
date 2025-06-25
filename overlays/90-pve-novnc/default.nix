# Proxmox's novnc uses a patched version of libvncserver,
# as of 1.9.0, the patch is only compatible with libvncserver <= 0.9.14

{ ... }:

self: super: rec {
  vncterm = super.vncterm.override {
    libvncserver = super.libvncserver.overrideAttrs (_: rec {
      version = "0.9.14";
      src = super.fetchFromGitHub {
        owner = "LibVNC";
        repo = "libvncserver";
        rev = "LibVNCServer-${version}";
        sha256 = "sha256-kqVZeCTp+Z6BtB6nzkwmtkJ4wtmjlSQBg05lD02cVvQ=";
      };
    });
  };

  pve-qemu-server = super.pve-qemu-server.override { inherit vncterm; };
  pve-ha-manager = super.pve-ha-manager.override { inherit pve-qemu-server; };
  pve-manager = super.pve-manager.override { inherit pve-ha-manager; };
  proxmox-ve = super.proxmox-ve.override {
    inherit
      pve-ha-manager
      pve-manager
      pve-qemu-server
      vncterm
      ;
  };
}
