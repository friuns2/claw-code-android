#!/usr/bin/env bash
# dogfood-build.sh — Build claw from current checkout and verify provenance.
# Usage: bash scripts/dogfood-build.sh
# On success: prints the verified binary path. Use as:
#   CLAW=$(bash scripts/dogfood-build.sh) && $CLAW version --output-format json
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUST_DIR="$REPO_ROOT/rust"
BINARY="$RUST_DIR/target/debug/claw"
EXPECTED_SHA="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"

echo "▶ Building claw from $REPO_ROOT ($(git -C "$REPO_ROOT" log --oneline -1))..." >&2
cargo build --manifest-path "$RUST_DIR/Cargo.toml" -p rusty-claude-cli -q

if [[ ! -x "$BINARY" ]]; then
    echo "✗ Build succeeded but binary not found at $BINARY" >&2
    exit 1
fi

BINARY_SHA=$("$BINARY" version --output-format json 2>/dev/null \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('git_sha','null'))" 2>/dev/null || echo "null")

if [[ "$BINARY_SHA" == "null" || -z "$BINARY_SHA" ]]; then
    echo "✗ Provenance check failed: binary reports git_sha: null" >&2
    echo "  Binary: $BINARY" >&2
    exit 1
fi

if [[ "$BINARY_SHA" != "$EXPECTED_SHA" ]]; then
    echo "✗ Provenance mismatch: binary=$BINARY_SHA, HEAD=$EXPECTED_SHA" >&2
    echo "  Rerun after 'git pull' or check for uncommitted changes." >&2
    exit 1
fi

echo "✓ Binary verified: $BINARY_SHA == HEAD ($EXPECTED_SHA)" >&2
echo "  To dogfood: export CLAW=$BINARY" >&2
echo "$BINARY"
