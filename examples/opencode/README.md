# opencode with a cloud provider

Run [opencode](https://opencode.ai) inside airlock against a **cloud model
provider** — Anthropic, OpenAI, OpenRouter, Google, and the 75+ others
opencode supports. This is the general-purpose setup; for a fully local,
no-egress alternative see [`../opencode-local`](../opencode-local).

## The image

opencode isn't in the stock airlock image, so you supply it. The image is
**identical** to the local example's — the same standalone opencode binary
works for both — so just build that Dockerfile:

```bash
docker build -t opencode-sandbox:local -f ../opencode-local/opencode.dockerfile ../opencode-local
```

Build on the same architecture your airlock VM uses (arm64 on Apple Silicon,
which is Docker's default there). The build needs network.

## Log in

The `opencode` preset injects no API key from the host. Instead you
authenticate **inside the sandbox**, once — opencode persists the credential
to `~/.airlock/opencode/data/` on the host, so later runs reuse it:

```bash
airlock start --monitor -- opencode auth login
```

Pick your provider and paste the key (or complete the OAuth flow).

## Run

```bash
airlock start --monitor -- opencode
```

airlock finds `opencode-sandbox:local` in the local Docker daemon
(`resolution = "auto"`), applies the `opencode` preset (open egress + config
and data mounts), and starts opencode with your saved login.

## Notes

- **Egress is open by default.** The preset sets
  `policy = "allow-by-default"` because opencode is provider-agnostic — it can
  reach whichever provider you configure, pull model metadata from
  `models.dev`, and fetch non-bundled provider SDKs from npm. To lock egress
  down to a single provider, override the policy in
  [`airlock.toml`](./airlock.toml) — see the opencode preset chapter in the
  manual for a worked deny-by-default example.
- **Pin a model** by editing `~/.airlock/opencode/opencode.json` on the host
  (e.g. `"model": "anthropic/claude-sonnet-4-5"`); your edits persist across
  runs.
