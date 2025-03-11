{ lib, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
  ];

  proxmoxLXC = {
    enable = true;
    privileged = false;
    manageNetwork = false;
    manageHostName = false;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
