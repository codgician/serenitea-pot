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

      programs.zsh = {
        oh-my-zsh = {
          enable = true;
          plugins = [ "git" "thefuck" ];
          theme = "half-life";
        };
      };
    };
  };
}
