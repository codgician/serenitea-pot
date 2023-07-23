{ config, pkgs, ... }: {
  # Enable nix daemon
  nix.useDaemon = true;

  # Garbage collection
  nix.gc = {
    automatic = true;
    interval.Hour = 24 * 7;
  };

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

    casks = [ 
      "qv2ray" "visual-studio-code" "microsoft-edge"
      "iina" "minecraft" "bilibili"
    ];
  };

  # Home manager
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.codgi = { config, pkgs, ... }: {
      home.stateVersion = "23.05";
      home.packages = with pkgs; [ xray ];
      
      programs.zsh = {
        enable = true;
        enableCompletion = true;
        oh-my-zsh = {
          enable = true;
          plugins = [ "git" ];
          theme = "half-life";
        };
      };
    };
  };
}
