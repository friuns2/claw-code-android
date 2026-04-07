# Claw Code Usage

This guide covers the current Rust workspace under `rust/` and the `claw` CLI binary. If you are brand new, make the doctor health check your first run: start `claw`, then run `/doctor`.

## Quick-start health check

Run this before prompts, sessions, or automation:

```bash
cd rust
cargo build --workspace
./target/debug/claw
# first command inside the REPL
/doctor
```

`/doctor` is the built-in setup and preflight diagnostic. Once you have a saved session, you can rerun it with `./target/debug/claw --resume latest /doctor`.

## Prerequisites

- Rust toolchain with `cargo`
- One of:
  - `ANTHROPIC_API_KEY` for direct API access
  - `claw login` for OAuth-based auth
- Optional: `ANTHROPIC_BASE_URL` when targeting a proxy or local service

## Install / build the workspace

```bash
cd rust
cargo build --workspace
```

The CLI binary is available at `rust/target/debug/claw` after a debug build. Make the doctor check above your first post-build step.

## Quick start

### First-run doctor check

```bash
cd rust
./target/debug/claw
/doctor
```

### Interactive REPL

```bash
cd rust
./target/debug/claw
```

### One-shot prompt

```bash
cd rust
./target/debug/claw prompt "summarize this repository"
```

### Shorthand prompt mode

```bash
cd rust
./target/debug/claw "explain rust/crates/runtime/src/lib.rs"
```

### JSON output for scripting

```bash
cd rust
./target/debug/claw --output-format json prompt "status"
```

## Model and permission controls

```bash
cd rust
./target/debug/claw --model sonnet prompt "review this diff"
./target/debug/claw --permission-mode read-only prompt "summarize Cargo.toml"
./target/debug/claw --permission-mode workspace-write prompt "update README.md"
./target/debug/claw --allowedTools read,glob "inspect the runtime crate"
```

Supported permission modes:

- `read-only`
- `workspace-write`
- `danger-full-access`

Model aliases currently supported by the CLI:

- `opus` → `claude-opus-4-6`
- `sonnet` → `claude-sonnet-4-6`
- `haiku` → `claude-haiku-4-5-20251213`

## Authentication

### API key

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
```

### OAuth

```bash
cd rust
./target/debug/claw login
./target/debug/claw logout
```

## Local Models

`claw` can talk to local servers and provider gateways through either Anthropic-compatible or OpenAI-compatible endpoints. Use `ANTHROPIC_BASE_URL` with `ANTHROPIC_AUTH_TOKEN` for Anthropic-compatible services, or `OPENAI_BASE_URL` with `OPENAI_API_KEY` for OpenAI-compatible services. OAuth is Anthropic-only, so when `OPENAI_BASE_URL` is set you should use API-key style auth instead of `claw login`.

### Anthropic-compatible endpoint

```bash
export ANTHROPIC_BASE_URL="http://127.0.0.1:8080"
export ANTHROPIC_AUTH_TOKEN="local-dev-token"

cd rust
./target/debug/claw --model "claude-sonnet-4-6" prompt "reply with the word ready"
```

### OpenAI-compatible endpoint

```bash
export OPENAI_BASE_URL="http://127.0.0.1:8000/v1"
export OPENAI_API_KEY="local-dev-token"

cd rust
./target/debug/claw --model "qwen2.5-coder" prompt "reply with the word ready"
```

### Ollama

```bash
export OPENAI_BASE_URL="http://127.0.0.1:11434/v1"
unset OPENAI_API_KEY

cd rust
./target/debug/claw --model "llama3.2" prompt "summarize this repository in one sentence"
```

### OpenRouter

```bash
export OPENAI_BASE_URL="https://openrouter.ai/api/v1"
export OPENAI_API_KEY="sk-or-v1-..."

cd rust
./target/debug/claw --model "openai/gpt-4.1-mini" prompt "summarize this repository in one sentence"
```

## HTTP proxy support

`claw` honours the standard `HTTP_PROXY`, `HTTPS_PROXY`, and `NO_PROXY` environment variables (both upper- and lower-case spellings are accepted) when issuing outbound requests to Anthropic, OpenAI-, and xAI-compatible endpoints. Set them before launching the CLI and the underlying `reqwest` client will be configured automatically.

```bash
export HTTPS_PROXY="http://proxy.corp.example:3128"
export HTTP_PROXY="http://proxy.corp.example:3128"
export NO_PROXY="localhost,127.0.0.1,.corp.example"

cd rust
./target/debug/claw prompt "hello via the corporate proxy"
```

Notes:

- When both `HTTPS_PROXY` and `HTTP_PROXY` are set, the secure proxy applies to `https://` URLs and the plain proxy applies to `http://` URLs.
- `NO_PROXY` accepts a comma-separated list of host suffixes (for example `.corp.example`) and IP literals.
- Empty values are treated as unset, so leaving `HTTPS_PROXY=""` in your shell will not enable a proxy.
- If a proxy URL cannot be parsed, `claw` falls back to a direct (no-proxy) client so existing workflows keep working; double-check the URL if you expected the request to be tunnelled.

## Common operational commands

```bash
cd rust
./target/debug/claw status
./target/debug/claw sandbox
./target/debug/claw agents
./target/debug/claw mcp
./target/debug/claw skills
./target/debug/claw system-prompt --cwd .. --date 2026-04-04
```

## Session management

REPL turns are persisted under `.claw/sessions/` in the current workspace.

```bash
cd rust
./target/debug/claw --resume latest
./target/debug/claw --resume latest /status /diff
```

Useful interactive commands include `/help`, `/status`, `/cost`, `/config`, `/session`, `/model`, `/permissions`, and `/export`.

## Config file resolution order

Runtime config is loaded in this order, with later entries overriding earlier ones:

1. `~/.claw.json`
2. `~/.config/claw/settings.json`
3. `<repo>/.claw.json`
4. `<repo>/.claw/settings.json`
5. `<repo>/.claw/settings.local.json`

## Mock parity harness

The workspace includes a deterministic Anthropic-compatible mock service and parity harness.

```bash
cd rust
./scripts/run_mock_parity_harness.sh
```

Manual mock service startup:

```bash
cd rust
cargo run -p mock-anthropic-service -- --bind 127.0.0.1:0
```

## Verification

```bash
cd rust
cargo test --workspace
```

## Workspace overview

Current Rust crates:

- `api`
- `commands`
- `compat-harness`
- `mock-anthropic-service`
- `plugins`
- `runtime`
- `rusty-claude-cli`
- `telemetry`
- `tools`
