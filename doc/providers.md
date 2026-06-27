<!-- markdownlint-disable MD013 -->

# Rotation providers

A rotation provider is a script that generates a new credential when
`bwx rotate` is called. Each secret in Bitwarden Secrets Manager can
declare which provider handles its rotation by setting a `provider:`
field in its note metadata.

- [Rotation providers](#rotation-providers)
  - [How rotation works](#how-rotation-works)
  - [Assigning a provider to a secret](#assigning-a-provider-to-a-secret)
  - [Credential passing](#credential-passing)
    - [Resolution chain](#resolution-chain)
    - [Examples](#examples)
  - [Input scrubbing](#input-scrubbing)
  - [Provider reference](#provider-reference)
    - [Automated providers](#automated-providers)
      - [`password-generate`](#password-generate)
      - [`mqtt-password`](#mqtt-password)
      - [`aws-iam`](#aws-iam)
      - [`openssl-selfsigned`](#openssl-selfsigned)
      - [`bitwarden-api-key`](#bitwarden-api-key)
      - [`grafana-service-account`](#grafana-service-account)
      - [`docker-registry`](#docker-registry)
      - [`tailscale-oauth`](#tailscale-oauth)
    - [Interactive providers](#interactive-providers)
      - [`anthropic-api-key`](#anthropic-api-key)
      - [`github-pat`](#github-pat)
      - [`letsencrypt-manual`](#letsencrypt-manual)
      - [`tailscale-manual`](#tailscale-manual)
      - [`prompt`](#prompt)
  - [Writing a custom provider](#writing-a-custom-provider)

## How rotation works

```text
bwx rotate SECRET
  1. Read the secret's note to find the provider: field
  2. Source lib/providers/<provider>
  3. Validate and scrub all config fields from the note
  4. Call bwx-provider-<name> SECRET SECRETS_DIR NOTE
  5. Validate PROVIDER_VALUE and PROVIDER_EXPIRES
  6. Update BWS value and note metadata (expires:, provider:)
```

When no `provider:` field is set, the `prompt` driver is used as a
generic fallback.

`bwx rotate --all` iterates over every secret that has an `expires:`
field and rotates those within the warning window.

## Assigning a provider to a secret

Set the `provider:` field in the secret's BWS note:

```bash
bwx secret set note my_secret_v1 "$(cat <<EOF
file: my-credential
provider: password-generate
password-length: 48
password-charset: alphanumeric
EOF
)"
```

After the first rotation, `bwx rotate` automatically maintains the
`expires:` and `provider:` fields in the note.

## Credential passing

Providers that call external APIs need credentials (OAuth secrets,
admin passwords, API keys). These credentials are configured in the
BWS note alongside the provider name, using a resolution protocol
that supports multiple credential sources.

### Resolution chain

When a provider config field has type `credential`, its value is
resolved through this chain:

| Format | Resolution | Example |
|--------|------------|---------|
| `PROJECT:SECRET` | BWS secret value lookup | `myproject:grafana_admin_pw_v1` |
| `/absolute/path` | Read file contents | `/opt/secrets/admin-pw` |
| `./relative/path` | Read file contents | `./.secrets/admin-pw` |
| `@env:VAR_NAME` | Environment variable | `@env:GRAFANA_ADMIN_PASSWORD` |
| *(anything else)* | Literal value | `my-password-here` |

For the `PROJECT:SECRET` form, both the project name and the secret
name are validated by the BWS API — the project must be accessible
with the current `BWS_ACCESS_TOKEN`, and the secret must exist in
that project. This is bwx eating its own dogfood: provider
credentials are managed the same way as any other secret.

### Examples

Grafana service account token with credentials stored in BWS:

```text
file: grafana-api-token
provider: grafana-service-account
grafana-url: http://grafana.internal:3000
grafana-sa-id: 42
grafana-admin-password: myproject:grafana_admin_password_v1
```

Docker Hub token with credentials in local files:

```text
file: docker-hub-pat
provider: docker-registry
docker-hub-username: ./.secrets/docker-hub-username
docker-hub-password: ./.secrets/docker-hub-password
```

Bitwarden API key with organization ID from an env var:

```text
file: bws-access-token
provider: bitwarden-api-key
bitwarden-org-id: @env:BWS_ORG_ID
bitwarden-machine-account-id: ./.secrets/bitwarden-machine-account-id
```

## Input scrubbing

All provider config values pass through a scrubbing layer before
reaching provider code. The scrub rejects values containing:

- `$` (dollar sign) — prevents `$(command)` and `${variable}` expansion
- `` ` `` (backtick) — prevents `` `command` `` expansion
- `\` (backslash) — prevents escape sequence injection
- newlines — config values are single-line

No legitimate config value (URL, hostname, token label, integer)
needs these characters. **Credential values** (the resolved content
of a secret, file, or env var) are NOT scrubbed — secret content may
contain any byte.

## Provider reference

### Automated providers

These providers require no operator interaction and work with
`bwx rotate --all`.

---

#### `password-generate`

Generates a cryptographically random password from `/dev/urandom`.

**Note fields:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `password-length` | integer (8–256) | `32` | Password length |
| `password-charset` | enum | `alphanumeric+symbols` | `alphanumeric` or `alphanumeric+symbols` |

**Default expiry:** 365 days

**Example note:**

```text
provider: password-generate
password-length: 48
password-charset: alphanumeric
```

---

#### `mqtt-password`

Generates a 32-character random alphanumeric password suitable for
MQTT broker authentication.

**Note fields:** None

**Default expiry:** 365 days

---

#### `aws-iam`

Rotates an AWS IAM access key. Creates a new key, returns the secret
key, and deactivates the old key.

**Prerequisites:** `aws` CLI or Docker (image: `amazon/aws-cli`)

**Note fields:** None — uses AWS CLI credential chain (`~/.aws/`,
environment variables)

**Default expiry:** 365 days

**Behavior:** The old key is deactivated (not deleted) after the new
key is created. Manual cleanup of inactive keys is left to the
operator.

---

#### `openssl-selfsigned`

Generates a self-signed TLS certificate or private key. For
multi-artifact rotation, create one BWS secret per artifact (cert
and key) with distinct `provider-role:` values.

**Prerequisites:** `openssl` or Docker (image: `alpine/openssl`)

**Note fields:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `provider-role` | enum | `cert` | `cert` or `key` |
| `cert-cn` | string | `bwx-selfsigned` | Certificate common name |
| `cert-days` | integer (1–3650) | `365` | Validity period in days |

**Default expiry:** matches `cert-days`

**Example note (certificate):**

```text
provider: openssl-selfsigned
provider-role: cert
cert-cn: mqtt.example.com
cert-days: 365
```

**Example note (private key):**

```text
provider: openssl-selfsigned
provider-role: key
cert-cn: mqtt.example.com
cert-days: 365
```

---

#### `bitwarden-api-key`

Rotates a Bitwarden machine account access token via the Bitwarden
API. Requires the current `BWS_ACCESS_TOKEN` environment variable.

**Note fields:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `bitwarden-org-id` | credential | (required) | Organization ID |
| `bitwarden-machine-account-id` | credential | (required) | Machine account ID |

**Fallback:** when note fields are absent, reads from
`$SECRETS_DIR/bitwarden-org-id` and
`$SECRETS_DIR/bitwarden-machine-account-id`.

**Default expiry:** 365 days

---

#### `grafana-service-account`

Creates a new Grafana service account token via the Grafana HTTP
API.

**Note fields:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `grafana-url` | string | `http://localhost:3000` | Grafana base URL |
| `grafana-sa-id` | integer | (required) | Service account ID |
| `grafana-token-name` | string | `bwx-rotated` | Token name prefix |
| `grafana-admin-user` | credential | `admin` | Admin username |
| `grafana-admin-password` | credential | (required) | Admin password |

**Fallback:** when `grafana-admin-password` is absent from the note,
reads from `$SECRETS_DIR/grafana-admin-password`.

**Default expiry:** 365 days

---

#### `docker-registry`

Rotates a Docker Hub personal access token via the Hub API.

**Note fields:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `docker-token-label` | string | `bwx-rotated` | Token label prefix |
| `docker-hub-username` | credential | (required) | Hub username |
| `docker-hub-password` | credential | (required) | Hub password or existing PAT |

**Fallback:** when note fields are absent, reads from
`$SECRETS_DIR/docker-hub-username` and
`$SECRETS_DIR/docker-hub-password`.

**Default expiry:** 365 days

---

#### `tailscale-oauth`

Creates a new tagged Tailscale pre-auth key using OAuth client
credentials.

**Note fields:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `tailscale-oauth-client-id` | credential | (required) | OAuth client ID |
| `tailscale-oauth-client-secret` | credential | (required) | OAuth client secret |

**Fallback:** when note fields are absent, reads from
`$SECRETS_DIR/tailscale-oauth-client-id` and
`$SECRETS_DIR/tailscale-oauth-client-secret`.

**Default expiry:** 90 days

---

### Interactive providers

These providers require an operator at the terminal and prompt for
input. They validate format and set correct expiry defaults.

---

#### `anthropic-api-key`

Prompts for an Anthropic API key. Validates the `sk-ant-` prefix
and accepts a custom expiry.

**Default expiry:** 365 days

---

#### `github-pat`

Prompts for a GitHub fine-grained personal access token. Validates
`ghp_*` or `github_pat_*` prefix. Prints the console URL and
recommended settings before prompting.

**Default expiry:** 365 days

---

#### `letsencrypt-manual`

Prompts for a PEM certificate (multi-line, terminated by empty line
or EOF). Validates BEGIN/END CERTIFICATE markers and extracts the
certificate subject.

**Default expiry:** 90 days (matches Let's Encrypt certificate
lifetime)

---

#### `tailscale-manual`

Prompts for a Tailscale pre-auth key. Validates the `tskey-auth-`
prefix. Used for untagged keys (OAuth clients can only create tagged
keys).

**Default expiry:** 90 days

---

#### `prompt`

Generic fallback provider. Asks the operator to paste any value and
specify an expiry in days.

**Default expiry:** 90 days (operator can override)

---

## Writing a custom provider

See [extending.md](extending.md) for the provider contract, step-by-step
instructions, and the `bwx-provider-config` API for typed config
field parsing with credential resolution and input scrubbing.
