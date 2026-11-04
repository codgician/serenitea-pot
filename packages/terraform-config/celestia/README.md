# 🌠 Celestia

Resources on Azure.

## Akasha model deployments

Manage Azure AI model deployments in [`cognitive/akasha/models.nix`](cognitive/akasha/models.nix).
Deployments include Claude Opus, Sonnet, and Haiku 5.5. The optional `registry`
attribute controls whether a deployment is also exposed in the shared model
registry; deployments without it are managed only by Terraform.
