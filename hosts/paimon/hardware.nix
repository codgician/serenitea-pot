{ lib, modulesPath, ... }: {
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
  ];

  proxmoxLXC = {
    privileged = false;
    manageNetwork = false;
    manageHostName = false;
  };

  nixpkgs.hostPlatform = lib.mkDefault {
    gcc.arch = "x86-64-v3";
    system = "x86_64-linux";
  };
}
