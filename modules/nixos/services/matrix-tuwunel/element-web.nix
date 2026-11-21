{
  pkgs,
  element-web,
  clientConfig ? { },
  domains ? [ ],
  ...
}:

pkgs.runCommand "element-web-codgician-me" { nativeBuildInputs = [ pkgs.buildPackages.jq ]; } (
  builtins.concatStringsSep "\n" (
    [
      ''
        cp -r ${element-web} $out
        chmod -R u+w $out
        jq '."default_server_config" = ${builtins.toJSON clientConfig}' \
          > $out/config.json < ${element-web}/config.json
      ''
    ]
    ++ (builtins.map (x: "ln -s $out/config.json $out/config.${x}.json") domains)
  )
)
