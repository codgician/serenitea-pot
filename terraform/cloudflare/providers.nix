{
  terraform = {
    required_providers.cloudflare = {
      source = "cloudflare/cloudflare";
      version = "~> 4.0";
    };
  };

  provider.cloudflare = {
    # Cloudflare API token provided via CLOUDFLARE_API_TOKEN
    # Cloudflare email provided via CLOUDFLARE_EMAIL
    retries = 3;
  };
}
