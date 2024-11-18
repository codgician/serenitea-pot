{ lib, pkgs, ... }: {

  # My settings
  codgician = {
    services = {
      nixos-vscode-server.enable = true;
    };

    system = {
      auto-upgrade.enable = true;
      impermanence.enable = true;
      secure-boot.enable = true;
    };

    users.codgi = with lib.codgician; {
      enable = true;
      hashedPasswordAgeFile = secretsDir + "/codgiHashedPassword.age";
      extraGroups = [ "wheel" ];
    };
  };

  # Home manager
  home-manager.users.codgi = { config, ... }: {
    codgician.codgi = {
      dev.nix.enable = true;
      git.enable = true;
      pwsh.enable = true;
      ssh.enable = true;
      zsh.enable = true;
    };

    home.stateVersion = "24.11";
    home.packages = with pkgs; [ httplz screen ];
  };

  # Use systemd-boot boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Allow RAID-1 esp boot
  boot.swraid = {
    enable = true;
    mdadmConf = "MAILADDR codgi";
  };

  # ZFS configurations
  services.zfs = {
    autoScrub.enable = true;
    autoSnapshot.enable = false;
    expandOnBoot = "all";
    trim.enable = true;
  };

  # ZFS on root boot configs
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.requestEncryptionCredentials = true;
  fileSystems."/nix/persist".neededForBoot = true;
  boot.plymouth.enable = false;

  networking.hostId = "4b6c6565";

  # TPM
  security.tpm2 = {
    enable = true;
    abrmd.enable = true;
    pkcs11.enable = true;
  };

  # Watchdog
  systemd.watchdog = {
    device = "/dev/watchdog0";
    runtimeTime = "30s";
    rebootTime = "600s";
  };

  # Firmware updates
  services.fwupd.enable = true;

  # Global packages
  environment.systemPackages = with pkgs; [
    lm_sensors
    smartmontools
    linuxPackages.turbostat
  ];

  # Enable zram swap
  zramSwap.enable = true;

  # Firewall
  networking.firewall.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
