# opencode with local inference

A minimal, self-contained image for running [opencode](https://opencode.ai)
inside airlock against a **local inference server on the host** (Ollama, LM
Studio, or llama.cpp) — with the network otherwise denied.

## Why a custom image

The stock airlock image doesn't ship opencode, so this image adds it. opencode
is distributed as a single standalone binary that bundles both its Bun runtime
**and** the `@ai-sdk/openai-compatible` provider, so an OpenAI-compatible local
server works with **no network beyond the host model server** — nothing is
fetched from npm at run time. That means it runs fine under airlock's
`deny-by-default` policy with no cache to pre-warm.

The [`opencode.dockerfile`](./opencode.dockerfile) is a two-stage build, split
only to keep the runtime lean:

- **builder** — downloads the opencode binary (needs network + `curl`).
- **runtime** — a small glibc image (`debian:trixie-slim`) with just `git`,
  CA certs, and the binary. No Node/Bun.

Alpine/musl would shrink the base, but opencode has
[known runtime issues on musl](https://github.com/sst/opencode/issues/649), and
the ~100 MB opencode binary dominates the image size regardless, so glibc is the
better trade-off.

> **Note:** the bundled `@ai-sdk/openai-compatible` provider covers Ollama, LM
> Studio, and llama.cpp. *Other* providers whose npm package is not bundled
> (some plugins, less common providers) are still fetched from npm on first use
> — for those you'd pre-install the package in the builder stage, or add the
> `nodejs` preset so the one-time fetch can reach the registry.

## Prerequisites

A local inference server running on the host. For Ollama:

```bash
ollama serve                       # listens on 127.0.0.1:11434
ollama pull qwen2.5-coder          # or whatever model you want
```

The `opencode` preset forwards the common host ports into the sandbox
(`11434` Ollama, `1234` LM Studio, `8080` llama.cpp).

## Build

```bash
docker build -t opencode-sandbox:local -f opencode.dockerfile .
```

Build on the same architecture your airlock VM uses (arm64 on Apple Silicon,
which is Docker's default there). The build needs network; the resulting image
does not.

## Run

```bash
airlock start --monitor -- opencode
```

airlock finds `opencode-sandbox:local` in the local Docker daemon
(`resolution = "auto"`), applies the `opencode` preset (host port forwards +
config/data mounts), and starts opencode. Pick a model from one of the seeded
providers — e.g. the Ollama one.

## Customising the model

The seeded [`opencode.json`](./opencode.json) lists placeholder models. To change
them, edit the config the preset persists on the host at
`~/.airlock/opencode/opencode.json` — your edits survive across runs. Make the
model IDs match what you've pulled/loaded on the host.

## Notes

- **`deny-by-default`, not `deny-always`.** The latter blocks port forwards too,
  which would cut off the host inference server.
- **Verify offline behaviour** by running the image with `--network none`; a
  completion attempt will select the `ai-sdk` runtime and fail only on the
  connection to the (unreachable) server — proving no npm fetch is needed.
