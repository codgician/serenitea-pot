{ config, pkgs, ... }: {
  # Enable nix daemon
  nix.useDaemon = true;

  # Users
  users.users.codgi = {
    name = "codgi";
    description = "Shijia Zhang";
    home = "/Users/codgi";
  };

  # System packages
  environment.systemPackages = with pkgs; [
    direnv neofetch
  ];

  # Fonts
  fonts = {
    fontDir.enable = true;
    fonts = with pkgs; [ cascadia-code ];
  };

  programs.zsh.enable = true;

  # Homebrew casks
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
    };

    casks = [ ];
  };

  # Home manager
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.codgi = { config, pkgs, ... }: {
      home.stateVersion = "23.05";
      home.packages = with pkgs; [ ];
      
      programs.zsh = {
        enable = true;
        oh-my-zsh = {
          enable = true;
          plugins = [ "git" ];
          theme = "half-life";
        };
      };
    };
  };
}
