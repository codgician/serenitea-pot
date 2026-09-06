{ pkgs, ... }:

{
  terraform = {
    required_providers = {
      google = {
        source = "hashicorp/google";
        version = pkgs.unstable.terraform-providers.hashicorp_google.version;
      };
    };
  };

  provider.google = {
    project = "legendary-tonatiuh";
    region = "asia-northeast";
    # Service account key provided via GOOGLE_CREDENTIALS
  };
}
