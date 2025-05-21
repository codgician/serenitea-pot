{
  terraform = {
    required_providers = {
      google = {
        source = "hashicorp/google";
        version = "~>6.36";
      };
    };
  };

  provider.google = {
    project = "legendary-tonatiuh";
    region = "asia-northeast";
    # Service account key provided via GOOGLE_CREDENTIALS
  };
}
