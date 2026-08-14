# Split the opencode preset into `opencode` (cloud) and `opencode-local`

## Motivation

The initial opencode support shipped a single `opencode` preset wired
exclusively for **local** inference: it forwarded the host's Ollama / LM
Studio / llama.cpp ports into the sandbox, seeded an OpenAI-compatible config
pointing at `localhost`, and opened no egress. That is a great privacy-first
setup, but it isn't how most people run opencode — the tool is
provider-agnostic across 75+ cloud providers, and claiming the plain
`opencode` name for the local-only variant put the uncommon case in the
obvious slot.

## Change

Two presets now cover the two ways to run opencode:

- **`opencode`** (new, general-purpose) — cloud providers. opencode has no
  single API host to allow-list and no host credential to inject, so the
  preset opens egress with `policy = "allow-by-default"` and lets opencode
  manage its own auth: you run `opencode auth login` **inside** the sandbox
  once and the credential persists in the mounted data dir. Open egress also
  covers `models.dev` (model metadata) and npm (non-bundled provider SDKs
  fetched on first use), so any provider works out of the box.
- **`opencode-local`** (the former `opencode`, renamed) — the privacy-first,
  no-egress variant, unchanged in behaviour.

To keep the two from stepping on each other's persisted state, their host
mount sources now mirror the preset name: `~/.airlock/opencode/` for the
cloud preset and `~/.airlock/opencode-local/` for the local one. This matters
because the config mount uses `missing = "create-file"`: a shared path would
let whichever preset ran first seed the config, and if the cloud preset won,
the local preset would lose its seeded `localhost` provider blocks entirely.

## Why `allow-by-default` and not `deny-by-default` + an allow-list

opencode fans out to 75+ providers through the AI SDK; no curated host list
covers them, and pinning one would defeat the "generic" point of the preset.
`allow-by-default` (rather than `allow-always`) keeps explicit `deny` rules
working, so a user can still carve out blocked hosts, and the docs show the
deny-by-default + single-provider allow-list recipe for anyone who wants to
lock egress down. No credential middleware is involved, so airlock never
intercepts TLS here and providers' real certs validate directly;
`NODE_EXTRA_CA_CERTS` still points at the system root bundle so adding auth
middleware later needs no extra setup.

## Docs and examples

- Manual: `presets/opencode.md` rewritten for the cloud preset (auth flow,
  egress, a deny-by-default lock-down recipe); the old page moved to
  `presets/opencode-local.md` and reframed as the privacy-first option. Both
  are listed in `SUMMARY.md` and cross-link each other; the `presets.md`
  agent list describes both.
- Examples: `examples/opencode` → `examples/opencode-local` (preset name and
  `~/.airlock/opencode-local/` paths updated), and a new lean
  `examples/opencode` for the cloud case that reuses the local example's
  Dockerfile — the opencode binary is identical, only the preset and policy
  differ.

## Tests

`config::tests::all_bundled_presets_are_valid` already resolves and parses
every bundled preset, so it now covers the new `opencode.toml` and the
renamed `opencode-local.toml` — a malformed policy value or mount would fail
it. No new test code was needed.
