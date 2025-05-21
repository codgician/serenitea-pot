{ config, ... }:
let
  depends_on = builtins.map (x: "google_project_service.${x}") (
    builtins.attrNames config.resource.google_project_service
  );
  mkRestrictions = builtins.map (service: {
    inherit service;
  });
in
{
  resource.google_apikeys_key = {
    # Custom search
    akasha-pse-key = {
      name = "akasha-pse";
      display_name = "Akasha Search";
      inherit depends_on;
      restrictions.api_targets = mkRestrictions [
        "customsearch.googleapis.com"
      ];
    };

    # Google Maps
    akasha-maps-key = {
      name = "akasha-maps";
      display_name = "Akasha Maps";
      inherit depends_on;
      restrictions.api_targets = mkRestrictions [
        "maps-backend.googleapis.com"
        "static-maps-backend.googleapis.com"
        "places-backend.googleapis.com"
        "geocoding-backend.googleapis.com"
        "distance-matrix-backend.googleapis.com"
      ];
    };

    # Vertex AI / Vision AI
    akasha-vertex-ai-key = {
      name = "akasha-vertex-ai";
      display_name = "Akasha Vertex AI";
      inherit depends_on;
      restrictions.api_targets = mkRestrictions [
        "aiplatform.googleapis.com"
        "visionai.googleapis.com"
      ];
    };
  };
}
