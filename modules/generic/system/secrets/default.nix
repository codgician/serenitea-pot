{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.secrets;
  inherit (pkgs.stdenvNoCC) isDarwin;

  dataDir = lib.codgician.secretsDir + "/data";
  templateDir = lib.codgician.secretsDir + "/templates";
  registry = import (lib.codgician.secretsDir + "/secrets.nix");
  secretsByKey = builtins.listToAttrs (
    lib.mapAttrsToList (name: secret: {
      name = secret.key;
      value = { inherit name secret; };
    }) registry.secrets
  );
  sentinel = name: "<SOPS:${name}:PLACEHOLDER>";
  parseRefs =
    content:
    lib.unique (
      map builtins.head (
        builtins.filter builtins.isList (builtins.split "<SOPS:([a-z0-9-]+):PLACEHOLDER>" content)
      )
    );
  templates =
    lib.mapAttrs'
      (
        fileName: _:
        let
          name = lib.removeSuffix ".nix" fileName;
          file = templateDir + "/${fileName}";
          template = import file { ref = sentinel; };
          refs = parseRefs template.content;
          unknown = builtins.filter (secret: !(builtins.hasAttr secret registry.secrets)) refs;
        in
        lib.nameValuePair name (
          lib.throwIf (unknown != [ ])
            "Template ${fileName} references undeclared secrets: ${lib.concatStringsSep ", " unknown}"
            (template // { inherit file refs; })
        )
      )
      (
        lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name) (
          builtins.readDir templateDir
        )
      );

  dataFiles = lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".json" name) (
    builtins.readDir dataDir
  );
  sourceEntries = lib.concatMap (
    fileName:
    let
      file = dataDir + "/${fileName}";
      data = builtins.fromJSON (builtins.readFile file);
    in
    map (
      key:
      let
        registered =
          secretsByKey.${key} or (throw "SOPS key ${key} is not declared in secrets/secrets.nix");
      in
      {
        inherit (registered) name secret;
        inherit fileName;
        value = {
          sopsFile = file;
          inherit key;
          format = "json";
        };
      }
    ) (builtins.attrNames (builtins.removeAttrs data [ "sops" ]))
  ) (builtins.attrNames dataFiles);
  sourceNames = map (entry: entry.name) sourceEntries;
  policyOf = secret: {
    hosts = map (recipient: recipient.name) secret.hosts;
    users = map (recipient: recipient.name) secret.users;
  };
  documentPoliciesMatch = lib.all (
    fileName:
    let
      entries = builtins.filter (entry: entry.fileName == fileName) sourceEntries;
      expected = policyOf (builtins.head entries).secret;
    in
    lib.all (entry: policyOf entry.secret == expected) entries
  ) (builtins.attrNames dataFiles);
  availableEntries = builtins.filter (
    entry: lib.any (host: host.name == config.networking.hostName) entry.secret.hosts
  ) sourceEntries;
  availableSources = builtins.listToAttrs (
    map (entry: {
      inherit (entry) name value;
    }) availableEntries
  );
  availableTemplates = lib.filterAttrs (
    _: template: lib.all (name: builtins.hasAttr name availableSources) template.refs
  ) templates;
  renderedTemplates = lib.mapAttrs (
    _: template:
    template
    // {
      content = (import template.file { ref = name: config.sops.placeholder.${name}; }).content;
    }
  ) availableTemplates;

  fileType = lib.types.submodule (
    { name, config, ... }:
    {
      options = {
        sopsFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Structured SOPS document containing secret ${name}.";
        };
        key = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "Key to extract from the structured SOPS document.";
        };
        format = lib.mkOption {
          type = lib.types.enum [
            "yaml"
            "json"
            "binary"
            "dotenv"
            "ini"
          ];
          default = "json";
        };
        owner = lib.mkOption {
          type = lib.types.str;
          default = "root";
        };
        group = lib.mkOption {
          type = lib.types.str;
          default = if isDarwin then "admin" else "root";
        };
        mode = lib.mkOption {
          type = lib.types.str;
          default = "0400";
        };
        neededForUsers = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        path = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          description = "Runtime path of the decrypted secret.";
        };
      };

      config.path =
        if config.neededForUsers then "/run/secrets-for-users/${name}" else "/run/secrets/${name}";
    }
  );
in
{
  options.codgician.secrets = {
    enable = lib.mkEnableOption "codgician sops-nix secrets" // {
      default = true;
    };
    files = lib.mkOption {
      type = lib.types.attrsOf fileType;
      default = { };
      description = "Secrets exposed as files by native sops-nix.";
    };
    templates = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options.path = lib.mkOption {
              type = lib.types.str;
              readOnly = true;
              default = "/run/secrets/rendered/${name}";
            };
          }
        )
      );
      default = { };
      description = "Native sops-nix templates available on this host.";
    };
  };

  config = lib.mkIf cfg.enable {
    codgician.secrets.files = availableSources;
    codgician.secrets.templates = lib.mapAttrs (_: _: { }) availableTemplates;

    assertions = [
      {
        assertion = builtins.length sourceNames == builtins.length (lib.unique sourceNames);
        message = "A secret key occurs in more than one structured SOPS document.";
      }
      {
        assertion =
          lib.sort builtins.lessThan sourceNames
          == lib.sort builtins.lessThan (builtins.attrNames registry.secrets);
        message = "secrets/data and secrets/secrets.nix declare different secrets.";
      }
      {
        assertion = documentPoliciesMatch;
        message = "Secrets sharing a SOPS document must have identical host and user policies.";
      }
    ]
    ++ lib.mapAttrsToList (name: file: {
      assertion = file.sopsFile != null;
      message = "codgician.secrets.files.${name} has no sopsFile.";
    }) cfg.files
    ++ lib.mapAttrsToList (name: file: {
      assertion = !file.neededForUsers || (file.owner == "root" && file.group == "root");
      message = "codgician.secrets.files.${name}: neededForUsers requires root:root ownership.";
    }) cfg.files;

    sops = {
      age.sshKeyPaths = lib.mkIf isDarwin [ "/etc/ssh/ssh_host_ed25519_key" ];

      secrets = lib.mapAttrs (_: file: {
        inherit (file)
          sopsFile
          key
          format
          owner
          group
          mode
          neededForUsers
          ;
      }) cfg.files;

      templates = lib.mapAttrs (
        _: template:
        {
          inherit (template) content;
        }
        // lib.optionalAttrs (template ? owner) { inherit (template) owner; }
        // lib.optionalAttrs (template ? group) { inherit (template) group; }
        // lib.optionalAttrs (template ? mode) { inherit (template) mode; }
      ) renderedTemplates;
    };
  };
}
