# opencode sandbox image for airlock (local inference).
#
# opencode ships as a single standalone binary that bundles both its Bun runtime
# AND the @ai-sdk/openai-compatible provider. An OpenAI-compatible local server
# (Ollama / LM Studio / llama.cpp) therefore works with NO network beyond the
# host model server — nothing is fetched from npm at run time — so the image
# runs fine under airlock's deny-by-default policy with no cache to pre-warm.
#
# The build is split in two stages purely to keep the runtime lean: the builder
# downloads the binary (which needs network + curl/unzip), and the runtime image
# carries only git + CA certs + the binary. opencode has known runtime issues on
# musl (github.com/sst/opencode/issues/649), so we use a glibc base; the ~100 MB
# binary dominates the image size regardless of base.

# ---- Stage 1: builder (download the opencode binary) ------------------------
FROM debian:trixie-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
        bash curl ca-certificates unzip \
    && rm -rf /var/lib/apt/lists/*

# The standalone installer auto-detects arch + libc. Copy the binary to a fixed
# path so the runtime stage doesn't depend on where the installer placed it.
RUN set -eux; \
    curl -fsSL https://opencode.ai/install | bash; \
    bin="$(find / -type f -name opencode 2>/dev/null | head -n1)"; \
    test -n "$bin"; \
    install -m 0755 "$bin" /usr/local/bin/opencode; \
    opencode --version

# ---- Stage 2: runtime -------------------------------------------------------
FROM debian:trixie-slim

# git: opencode uses it for repo context. ca-certificates: TLS trust for any
# HTTPS opencode makes. bash/coreutils ship with the base for opencode's shell
# tool. No Node/Bun needed — the opencode binary is self-contained.
RUN apt-get update && apt-get install -y --no-install-recommends \
        git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/bin/opencode /usr/local/bin/opencode
# A default config so the image is usable on its own. airlock's opencode preset
# shadows this with its own mounted opencode.json.
COPY opencode.json /root/.config/opencode/opencode.json

ENV HOME=/root
WORKDIR /workspace

CMD ["opencode"]
