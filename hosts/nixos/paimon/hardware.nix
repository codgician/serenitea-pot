{ lib, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
  ];

  proxmoxLXC = {
    enable = true;
    privileged = false;
    manageNetwork = true;
    manageHostName = true;
  };

  networking.useHostResolvConf = false;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
