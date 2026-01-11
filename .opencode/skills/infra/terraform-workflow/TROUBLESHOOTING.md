# Troubleshooting: Terraform Workflow

> See AGENTS.md for global troubleshooting principles.

## State drift (unexpected changes in plan)

**Cause**: Manual changes in cloud console

**Fix**: `terraform refresh` inside `tfmgr shell` - requires user approval.

---

## Resource already exists

**Cause**: Resource created outside Terraform

**Fix**: `terraform import` inside `tfmgr shell` - requires user approval with resource ID confirmation.

---

## Authentication failed

**Action**: Ask user to resolve credentials. Do not rotate secrets automatically.

After user confirms new credentials: ask approval to update `secrets/terraform-env.age`.

---

## "Invalid reference" in plan

**Cause**: Using Terraform interpolation instead of Nix attribute access

**Wrong**: `zone_id = "\${cloudflare_zone.codgician-me.id}";`
**Correct**: `zone_id = config.resource.cloudflare_zone.codgician-me "id";`

---

## Resource replacement (-/+) unexpected

**Cause**: Changing immutable attribute forces replacement

**Action**: Stop and ask user - may cause data loss or downtime.

---

## "No such file" for .tf

**Cause**: Terranix didn't generate config

**Fix**: Check Nix syntax:
```bash
nix eval .#packages.x86_64-linux.terraform-config
```

---

## DNS not resolving after apply

**Causes**: Propagation delay (5-10 min), wrong record type, Cloudflare proxy settings

**Check**: `dig @1.1.1.1 myservice.codgician.me`

---

## Can't destroy resource

`terraform state rm` and `terraform destroy -target` require user approval per AGENTS.md principles.

Always run inside `tfmgr shell`.
