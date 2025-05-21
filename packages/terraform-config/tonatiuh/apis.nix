{ config, ... }:
let
  services = [
    "apikeys.googleapis.com"

    # Custom search
    "customsearch.googleapis.com"

    # Maps
    "maps-backend.googleapis.com"
    "static-maps-backend.googleapis.com"
    "places-backend.googleapis.com"
    "geocoding-backend.googleapis.com"
    "distance-matrix-backend.googleapis.com"

    # Vertex AI / Vision AI
    "aiplatform.googleapis.com"
    "visionai.googleapis.com"
  ];
in
{
  resource.google_project_service = builtins.listToAttrs (
    builtins.map (service: {
      name = "api-${builtins.head (builtins.match "^([^.]+).*$" service)}";
      value = {
        inherit service;
        inherit (config.provider.google) project;
      };
    }) services
  );
}
