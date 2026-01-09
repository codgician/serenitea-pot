# Terraform Config (Terranix)

Infrastructure-as-Code using Terranix (Nix -> Terraform JSON).

## STRUCTURE

```
terraform-config/
├── default.nix           # Entry: auto-imports subdirs via getFolderPaths
├── celestia/             # Azure infrastructure
│   ├── providers.nix     # azurerm + azapi providers, blob backend
│   ├── networks.nix      # VNets, subnets
│   ├── storages/         # Storage accounts (primogems, constellation)
│   ├── vms/lumine/       # Azure VM definition
│   └── cognitive/akasha/ # AI model deployments (GPT-4o, DeepSeek, etc.)
├── cloudflare/           # DNS management
│   ├── providers.nix     # Cloudflare provider
│   └── zones/codgician-me/records/  # DNS records
└── tonatiuh/             # Google Cloud Platform
    ├── providers.nix     # Google provider
    ├── keys.nix          # KMS keys
    └── apis.nix          # Enabled APIs
```

## WHERE TO LOOK

| Task | Location |
|------|----------|
| Add DNS record | `cloudflare/zones/codgician-me/records/` |
| Add AI model | `celestia/cognitive/akasha/<model>.nix` |
| Add Azure resource | `celestia/<category>/` or new subdir |
| Add GCP resource | `tonatiuh/` |

## CONVENTIONS

### Resource Reference Pattern
```nix
# Instead of Terraform interpolation:
storage_account_id = config.resource.azurerm_storage_account.primogems "id";
```

### File Organization
- One `.nix` file per logical resource group
- `providers.nix` in each environment root
- `default.nix` auto-imports siblings

### Authentication
- Via environment variables: `ARM_CLIENT_SECRET`, `CLOUDFLARE_API_TOKEN`, `GOOGLE_CREDENTIALS`
- Managed in `secrets/terraform-env.age`

## COMMANDS

```bash
nix run .#tfmgr -- init      # Initialize terraform
nix run .#tfmgr -- plan      # Preview changes
nix run .#tfmgr -- apply     # Apply changes
```

## ANTI-PATTERNS

- Don't write raw `.tf` files - use Nix expressions
- Don't hardcode credentials - use env vars from secrets
- Don't forget to run `tfmgr` after Nix changes to regenerate JSON
