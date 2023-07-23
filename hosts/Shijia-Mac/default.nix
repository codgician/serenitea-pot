{ pkgs, ... }: {
  # if you use zsh (the default on new macOS installations),
  # you'll need to enable this so nix-darwin creates a zshrc sourcing needed environment changes
  programs.zsh = {
    enable = true;
  };

  # Homebrew casks
  homebrew = {
    enable = true;
    autoUpdate = true;
    # updates homebrew packages on activation,
    # can make darwin-rebuild much slower (otherwise i'd forget to do it ever though)
    casks = [ ];
  };

  # Home manager
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.codgi = {
      home.stateVersion = "23.05";
    };
  };
}
