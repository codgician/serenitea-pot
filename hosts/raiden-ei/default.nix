{ config, pkgs, ... }: {

  # My settings
  codgician = {
    system = {
      agenix.enable = true;
      brew = {
        enable = true;
        casks = [
          "bluebubbles"
          "opencore-configurator"
        ];
        masApps = { };
      };
    };

    users.codgi.enable = true;
  };

  # Nix garbage collection
  nix.gc = {
    automatic = true;
    interval = {
      Hour = 24 * 7;
      Minute = 0;
    };
  };

  # Home manager
  home-manager.users.codgi = { config, pkgs, ... }: {
    codgician.codgi = {
      git.enable = true;
      pwsh.enable = true;
      ssh.enable = true;
      zsh.enable = true;
    };

    home.stateVersion = "24.05";
    home.packages = with pkgs; [
      httplz
      iperf3
      aria2
      httping
    ];
  };

  # System packages
  environment.systemPackages = with pkgs; [ neofetch openssl ];

  # zsh
  programs.zsh = {
    enable = true;
    promptInit = "";
  };

  nixpkgs.config.allowUnfree = true;
}
