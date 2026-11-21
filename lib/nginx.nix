{ ... }:
{
  # Make a nginx location for hosting static files
  mkNginxLocationForStaticFile = path: {
    root = builtins.dirOf path;
    tryFiles = "/${builtins.baseNameOf path} =404";
    extraConfig = ''
      access_log off; 
      log_not_found off;
    '';
  };
}
