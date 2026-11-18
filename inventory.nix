# Facts that more than one host, module or flake output reads.
# Plain data: no `pkgs`, no module system.
rec {
  zone = "codgician.me";

  hosts = {
    fischl.system = "x86_64-linux";
    focalors = {
      system = "aarch64-linux";
      roles = [ "desktop" ];
    };
    furina.system = "aarch64-darwin";
    jahoda = {
      system = "x86_64-linux";
      roles = [ "desktop" ];
    };
    lumine = {
      system = "aarch64-linux";
      roles = [ "edge" ];
    };
    nahida = {
      system = "x86_64-linux";
      cudaSupport = true;
      lan = "192.168.0.23";
    };
    odette = {
      system = "x86_64-linux";
      roles = [ "desktop" ];
    };
    paimon = {
      system = "x86_64-linux";
      cudaSupport = true;
      lan = "192.168.0.22";
      pve = "192.168.0.21";
    };
    raiden-ei.system = "x86_64-darwin";
    sandrone = {
      system = "aarch64-linux";
      roles = [ "desktop" ];
    };
    wanderer.system = "x86_64-linux";
    xianyun = {
      system = "x86_64-linux";
      roles = [ "edge" ];
    };
    zibai.system = "x86_64-linux";
  };
}
