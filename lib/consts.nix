{ ... }: rec {
  # Path to root
  rootDir = ../.;

  # Path to modules folder
  modulesDir = rootDir + "/modules";

  # Path to modules folder
  hmModulesDir = rootDir + "/hm-modules";

  # Path to overlays folder
  overlaysDir = rootDir + "/overlays";

  # Path to secrets dirctory
  secretsDir = ../secrets;
}
