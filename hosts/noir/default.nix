{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware.nix

    # User
    ../../users/codgi/default.nix
  ];

  # Home manager
  home-manager.users.codgi = { config, pkgs, ... }: {
    imports = [
      ../../users/codgi/pwsh.nix
      ../../users/codgi/git.nix
      ../../users/codgi/ssh.nix
      ../../users/codgi/zsh.nix
    ];

    home.stateVersion = "23.11";
  };

  # Zsh
  programs.zsh = {
    enable = true;
    enableCompletion = true;
  };

  # 
  # Opinionated defaults
  #

  # Use Network Manager
  networking.wireless.enable = false;
  networking.networkmanager.enable = true;

  # Use PulseAudio
  hardware.pulseaudio.enable = true;

  # Enable Bluetooth
  hardware.bluetooth.enable = true;

  # Bluetooth audio
  hardware.pulseaudio.package = pkgs.pulseaudioFull;

  # Enable power management options
  powerManagement.enable = true;

  # It's recommended to keep enabled on these constrained devices
  zramSwap.enable = true;

  services.openssh = {
    enable = true;
    openFirewall = true;
  };

  #
  # User configuration
  #
  users.mutableUsers = false;
  users.users."codgi".extraGroups = [
    "dialout"
    "feedbackd"
    "networkmanager"
    "video"
    "wheel"
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}
