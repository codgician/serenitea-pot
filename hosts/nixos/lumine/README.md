# 🌸 Lumine

Azure VM (Gen 2) running NixOS, being the reverse proxy to almost every self-hosted service.

## LiteLLM

Claude Opus, Sonnet, and Haiku 5.5 share their existing public model names and
aliases across three deployment priorities: Claude OAuth first, the Anthropic
API key second, and Azure Akasha last. Azure is used only when the higher-priority
deployments fail or are unavailable, not for normal load balancing.

Provider HTTP 400 errors, including exhausted credits and invalid parameters,
also permit fallback. This policy applies globally to LiteLLM's model groups.

The container runs rootless under the host's `litellm` account. Podman's
`keep-id` mapping runs the application as container UID/GID `65532:65532` while
preserving host UID/GID `2025:2025`, including Redis socket permissions and
PostgreSQL peer authentication. Application state remains in `/var/lib/litellm`
without an ownership migration. Rootless container storage is persisted
separately in `/var/lib/litellm-podman`. Its user-specific `fuse-overlayfs`
configuration shifts image ownership at mount time, avoiding full-image copy-up
on ZFS when using `keep-id`.

Manage the container through `podman-litellm.service`. To inspect its rootless
Podman storage directly:

```bash
sudo -iu litellm env XDG_RUNTIME_DIR=/run/user/2025 podman ps
```

### Antigravity Gemini subscription

Gemini subscription requests use an external `CustomLLM` handler loaded through
`custom_provider_map`; LiteLLM itself is not patched. The registry exposes
`gemini-4-argon`, `gemini-4-carbon`, `gemini-3.8-flash`, and
`gemini-3.1-flash-lite`, matching the account's model roster. Reasoning effort
selects the corresponding SKU;
a SKU absent from the account's catalog returns an error, not another model.
Image-generation models continue using the Gemini API key.

Google has suspended Antigravity access for third-party OAuth use
([upstream report](https://github.com/can1357/oh-my-pi/issues/18341)). Connecting
an account accepts that risk; this is not a supported Google API integration.
Antigravity also answers `429 RESOURCE_EXHAUSTED` ("check quota") whenever the
system prompt contains a known third-party agent identity, such as omp's,
opencode's, or Claude Code's, while quota remains. Those clients cannot use
these models through the gateway; the same text in user turns is accepted.

The handler signs in as the native Antigravity client. Its OAuth client ID and
secret are not committed; the `antigravity-oauth-client-id` and
`antigravity-oauth-client-secret` SOPS secrets hold the values, injected through
the `litellm-env` template.

After deploying the handler, connect from an interactive terminal:

```bash
sudo -iu litellm env XDG_RUNTIME_DIR=/run/user/2025 \
  podman exec -it litellm python /antigravity_provider.py login
```

Open the printed authorization URL, then paste the full loopback redirect URL
back into the command; the loopback page need not load. The refresh token,
project, and account model catalog are written to
`/var/lib/litellm/antigravity/credentials.json` with mode `0600`, under the
existing persisted state directory. Workers share a file lock when refreshing
and atomically replace rotated tokens. Repeat login if Google revokes access.

For an unreliable SSH connection, run `login --start` first and later run
`login --finish` with the same command prefix. PKCE state is stored as a `0600`
file beside the credentials and removed after successful login; the callback
can therefore be submitted through a new SSH session.

If project provisioning or catalog discovery fails after authorization, tokens
remain in that private pending-login file. Resolve the Google account's access
or regional eligibility, then retry `login --finish` without reusing the
single-use authorization code. Existing working credentials are replaced only
after provisioning succeeds.

An active current tier takes precedence over an unrelated `free-tier` entry in
`ineligibleTiers`; paid accounts need not be eligible for free-tier onboarding.
Successful login and catalog discovery do not guarantee inference access.
Gemini generation is rejected with `FAILED_PRECONDITION` and `User location is not supported for the API use.` from lumine's Azure IPv6 egress, even though
the same request succeeds from its IPv4 egress in the same region. The handler
therefore binds all Google requests to IPv4. Other location rejections are
propagated rather than silently switching providers or models.

The handler reuses LiteLLM's Gemini message/tool/signature conversion. Streaming
ends with a generic usage chunk so cached and reasoning tokens survive all
three client protocols. Spend is API-equivalent pricing, not a subscription
invoice. The native-client model profile determines output limits; a smaller
client `max_tokens` is not guaranteed to be honored. Home Manager client model
allowlists are unchanged.

## Build VHD

To build system disk `.vhd` for uploading, run:

```bash
nix run .#mkimg -- -priv /path/to/host/ssh/privkey --ssh-dir /persist/etc/ssh -f vhd --fixed-size lumine
```

## Upload built VHD to Azure

Start development environment:

```bash
nix develop .#terraform
```

Login to Azure:

```bash
az login --use-device-code
az account set --subscription "d80e6deb-21e3-4aed-9455-5573a2086f66"
```

Upload built vhd to Azure Blob Storage using generated SAS:

```bash
end=`date -u -d "60 minutes" '+%Y-%m-%dT%H:%MZ'`
sas=$(az storage container generate-sas \
    --account-name "constellation" \
    --name "lumine" \
    --expiry $end \
    --permissions acdlrw \
    --auth-mode key | tr -d '"')
azcopy copy ./sda.vhd "https://constellation.blob.core.windows.net/lumine/?$sas" --blob-type PageBlob
```
