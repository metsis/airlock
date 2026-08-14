# opencode

The `opencode` preset bundles the sandbox setup for the
[opencode CLI](https://opencode.ai) running against **cloud model
providers** — Anthropic, OpenAI, OpenRouter, Google, Groq, and the 75+
others opencode supports through the AI SDK. This is the general-purpose
opencode preset: pick any provider, log in, and go.

opencode is provider-agnostic, so there is no single API host to allow-list
and no host credential to inject. The preset instead opens outbound network
by default and lets opencode manage its own authentication — you log in once
inside the sandbox and the credential persists across runs.

> Want a fully local, no-egress agent instead? The
> [`opencode-local`](./opencode-local.md) preset runs opencode against a
> local inference server on the host (Ollama / LM Studio / llama.cpp) and
> opens **no** outbound network at all. It's the privacy-first choice.

## What the preset does

- **Opens egress by default.** opencode reaches whichever provider you
  configure, pulls model metadata from `models.dev`, and fetches any
  provider SDK it doesn't already bundle from npm on first use. The preset
  sets `policy = "allow-by-default"`, so all of that works out of the box
  while explicit `deny` rules are still honoured (see
  [Locking egress down](#locking-egress-down)).

- **Keeps you logged in.** `~/.local/share/opencode` (sessions, projects,
  and the `auth.json` written by `opencode auth login`) is mapped to
  `~/.airlock/opencode/data/` on the host, so your provider logins survive
  between runs.

- **Persists your config.** The global config
  `~/.config/opencode/opencode.json` is mapped to
  `~/.airlock/opencode/opencode.json` on the host and seeded minimally — no
  provider block is required, since opencode discovers cloud providers from
  `models.dev` plus your login. Edit it on the host to pin a default `model`
  or add custom providers; your changes persist.

## Authentication

No API key is taken from the host environment. Instead, log in **inside the
sandbox** the first time:

```bash
airlock start --monitor -- opencode auth login
```

Pick your provider, paste the key (or complete the OAuth flow), and opencode
writes it to `auth.json` in the persisted data dir. Subsequent runs reuse it:

```bash
airlock start --monitor -- opencode
```

Because the credential lives only in the sandbox's persisted data dir, it is
never exposed to the guest through an environment variable, and rotating or
removing it is just an `opencode auth logout` (or deleting
`~/.airlock/opencode/data/auth.json` on the host).

## Example `airlock.toml`

```toml
presets = ["opencode"]

[vm]
image = "..."   # an image with opencode installed
```

The preset already sets the network policy, so no `[network]` block is
needed unless you want to tighten it.

## Installing opencode

opencode is not shipped in the stock image, so you supply it in the VM
image. It's distributed as a single standalone binary that bundles its Bun
runtime, so a minimal image with just the binary, `git`, and CA certificates
is enough — provider SDKs that aren't bundled are fetched from npm at run
time, which the open egress policy allows. The ready-to-build image and
Dockerfile in
[`examples/opencode-local`](https://github.com/milankinen/airlock/tree/main/examples/opencode-local)
work unchanged for cloud use; only the preset and network policy differ.

## Locking egress down

`allow-by-default` opens all outbound network, which is convenient across
opencode's many providers but broader than airlock's usual deny-by-default
posture. If you only use one provider, you can lock egress down to just what
opencode needs by overriding the policy in your project config:

```toml
presets = ["opencode"]

[network]
policy = "deny-by-default"

[network.rules.opencode-anthropic]
allow = [
    "api.anthropic.com:443",
    "models.dev:443",           # model metadata
]
```

Add the API host(s) for your provider (for example `api.openai.com:443` or
`openrouter.ai:443`) and `models.dev:443`. If opencode needs a provider SDK
it doesn't bundle, also allow the npm registry (or add the `nodejs` preset)
for the one-time fetch — or pre-install the package in your image.

## Adding or pinning providers

opencode discovers configured providers automatically, but you can pin a
default model or register a custom provider by editing the persisted config
on the host at `~/.airlock/opencode/opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "anthropic/claude-sonnet-4-5"
}
```

Your edits persist and the sandbox picks them up on the next run.
