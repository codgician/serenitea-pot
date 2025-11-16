{
  lib,
  pkgs,
  cfg,
  serviceName,
  ...
}:

(lib.codgician.mkServiceReverseProxyConfig {
  inherit serviceName cfg;
  extraVhostConfig.locations =
    let
      inherit (cfg.reverseProxy)
        appIcon
        favicon
        splash
        ;

      convertImage = lib.codgician.convertImage pkgs;
      resizeImage =
        size: outName: image:
        convertImage image {
          args = "-background transparent -resize ${size}";
          inherit outName;
        };

      faviconIco = convertImage favicon {
        args = "-background transparent -define icon:auto-resize=16,24,32,48,64,72,96,128,256";
        outName = "favicon.ico";
      };
      favicon96 = resizeImage "96x96" "favicon-96x96.png" favicon;
      favicon512 = resizeImage "512x512" "favicon" appIcon;

      mkNginxLocationForStaticFile = path: {
        root = builtins.dirOf path;
        tryFiles = "/${builtins.baseNameOf path} =404";
        extraConfig = ''
          access_log off; 
          log_not_found off;
        '';
      };
    in
    (lib.optionalAttrs (favicon != null) {
      "= /favicon.png".passthru = mkNginxLocationForStaticFile favicon512;
      "= /static/favicon.png".passthru = mkNginxLocationForStaticFile favicon512;
      "= /static/favicon-dark.png".passthru = mkNginxLocationForStaticFile favicon512;
      "= /static/favicon-96x96.png".passthru = mkNginxLocationForStaticFile favicon96;
      "= /favicon.ico".passthru = mkNginxLocationForStaticFile faviconIco;
      "= /static/favicon.ico".passthru = mkNginxLocationForStaticFile faviconIco;
    })
    // (lib.optionalAttrs (appIcon != null) {
      "= /static/logo.png".passthru = mkNginxLocationForStaticFile appIcon;
      "= /static/apple-touch-icon.png".passthru = mkNginxLocationForStaticFile (
        resizeImage "180x180" "apple-touch-icon.png" appIcon
      );
      "= /static/web-app-manifest-192x192.png".passthru = mkNginxLocationForStaticFile (
        resizeImage "192x192" "web-app-manifest-192x192.png" appIcon
      );
      "= /static/web-app-manifest-512x512.png".passthru = mkNginxLocationForStaticFile (
        resizeImage "512x512" "web-app-manifest-512x512.png" appIcon
      );
    })
    // (lib.optionalAttrs (splash != null) {
      "= /static/splash.png".passthru = mkNginxLocationForStaticFile splash;
      "= /static/splash-dark.png".passthru = mkNginxLocationForStaticFile splash;
    })
    // {
      "/".passthru.extraConfig = ''
        client_max_body_size 128M;
        proxy_buffering off;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        proxy_read_timeout 300;
        send_timeout 300;
      '';
      "~ ^/api/v1/files" = {
        inherit (cfg.reverseProxy) lanOnly;
        passthru = {
          inherit (cfg.reverseProxy) proxyPass;
          extraConfig = ''
            client_max_body_size 128M;
            proxy_connect_timeout 1800;
            proxy_send_timeout 1800;
            proxy_read_timeout 1800;
            send_timeout 1800;
          '';
        };
      };
    };
})
