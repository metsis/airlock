# opencode

The `opencode` preset bundles the sandbox setup for the
[opencode CLI](https://opencode.ai) running against a **local inference
server on the host** — Ollama, LM Studio, or llama.cpp. Instead of talking
to a cloud provider, opencode reaches a model server running on your own
machine, and no API key ever enters the sandbox.

Unlike the cloud agent presets, this one opens no outbound network access.
airlock stays deny-by-default; the only thing it lets through is a
loopback bridge to the inference server already running on your host.

## What the preset does

- **Reaches the host model server with the network otherwise denied.**
  The preset forwards the common inference ports from the host into the
  sandbox, so `localhost:<port>` inside the VM transparently reaches the
  server on your host. Guest → host port forwards bypass network rules
  entirely, so this works even under `deny-by-default` while every other
  destination stays blocked. Forwarded by default:

  | Server      | Port    |
  | ----------- | ------- |
  | Ollama      | `11434` |
  | LM Studio   | `1234`  |
  | llama.cpp   | `8080`  |

- **Seeds a starter config.** `~/.config/opencode/opencode.json` is created
  (only if missing) with an OpenAI-compatible provider entry for each of the
  three servers, pointing at `http://localhost:<port>/v1`. Edit the model
  IDs to match what you have pulled/loaded on the host.

- **Persists your session data.** `~/.local/share/opencode` (sessions,
  projects, `auth.json`) is mapped to `~/.airlock/opencode/data/` on the
  host, and the seeded config to `~/.airlock/opencode/opencode.json`, so both
  carry over between runs.

## Requires `deny-by-default`, not `deny-always`

The host port forwards this preset relies on are blocked by
`policy = "deny-always"`, which denies *everything* including forwards and
sockets. Use `deny-by-default` (the recommended policy) so the loopback
bridge to your inference server works while all real network egress stays
denied.

## Example `airlock.toml`

```toml
presets = ["opencode"]

[network]
policy = "deny-by-default"

[vm]
image = "..."   # an image with opencode installed
```

## Installing opencode

opencode is not shipped in the stock image, so you supply it in the VM
image. It's distributed as a single standalone binary that bundles both its
Bun runtime **and** the `@ai-sdk/openai-compatible` provider, so an
OpenAI-compatible local server (Ollama / LM Studio / llama.cpp) works with
**no network beyond the host model server** — nothing is fetched from npm at
run time. A ready-to-build image and Dockerfile are in
[`examples/opencode`](https://github.com/milankinen/airlock/tree/main/examples/opencode).

> Providers whose npm package is *not* bundled (some plugins, less common
> providers) are still fetched from npm on first use. For those, pre-install
> the package in your image, or add the `nodejs` preset so the one-time fetch
> can reach the registry.

If opencode complains about model metadata, it may be trying to reach
`models.dev`. It is not required for a configured local provider, but you
can allow it explicitly if needed:

```toml
[network.rules.opencode-models-registry]
allow = ["models.dev:443"]
```

## Running it

```bash
airlock start --monitor -- opencode
```

Pick a model from one of the seeded providers (for example the Ollama
provider). If the seeded model IDs don't match what's available on the
host, edit `~/.airlock/opencode/opencode.json` on the host — your changes
persist and the sandbox picks them up on the next run.

## Adjusting the forwarded ports

If you only run one server — or a port collides with something else — disable
the ones you don't need rather than forwarding all three. Note that `8080`
(llama.cpp) is a common host dev port; while it's forwarded, guest
`localhost:8080` reaches your host's `:8080` instead of anything in the
sandbox.

```toml
# airlock.local.toml — forward only Ollama
[network.ports.opencode-inference]
host = [11434]
```
