{ config, lib, modulesPath, ... }: {
  imports =
    [
      (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ];

  proxmoxLXC = {
    privileged = false;
    manageNetwork = true;
    manageHostName = true;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
