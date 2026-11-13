#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1" needle="$2" message="$3"
  [[ "$haystack" == *"$needle"* ]] || fail "$message (missing: $needle)"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_EXAMPLE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT
EXAMPLE_DIR="$TEST_ROOT/example"
COMMAND_LOG="$TEST_ROOT/commands.log"
export COMMAND_LOG

# Exercise an isolated copy so a developer's ignored .env cannot affect the
# command contract test or expose real credentials to the test process.
mkdir -p "$EXAMPLE_DIR/scripts" "$EXAMPLE_DIR/skills/provider-billing-integrity"
cp "$SOURCE_EXAMPLE_DIR/scripts/_lib.sh" \
  "$SOURCE_EXAMPLE_DIR/scripts/onboard.sh" \
  "$SOURCE_EXAMPLE_DIR/scripts/install.sh" \
  "$SOURCE_EXAMPLE_DIR/scripts/start.sh" \
  "$SOURCE_EXAMPLE_DIR/scripts/stop.sh" \
  "$EXAMPLE_DIR/scripts/"

nemoclaw() {
  {
    printf 'sandbox=%q agent=%q args=' "${NEMOCLAW_SANDBOX_NAME:-}" "${NEMOCLAW_AGENT:-}"
    printf '%q ' "$@"
    printf '\n'
  } >>"$COMMAND_LOG"
}
export -f nemoclaw

openshell() {
  if [[ "$*" == "sandbox list --names" && "${FAKE_SANDBOX_EXISTS:-0}" == "1" ]]; then
    printf '%s\n' "${NEMOCLAW_SANDBOX_NAME:-billing-integrity}"
  fi
}
export -f openshell

export NEMOCLAW_SANDBOX_NAME=billing-integrity

: >"$COMMAND_LOG"
NVIDIA_INFERENCE_API_KEY=test-key bash "$EXAMPLE_DIR/scripts/onboard.sh" >/dev/null
assert_contains "$(cat "$COMMAND_LOG")" "agent=openclaw" \
  "onboard did not select the OpenClaw harness"
assert_contains "$(cat "$COMMAND_LOG")" "args=onboard --non-interactive --yes --name billing-integrity --no-sandbox-gpu" \
  "onboard did not create the named sandbox non-interactively"

: >"$COMMAND_LOG"
FAKE_SANDBOX_EXISTS=1 bash "$EXAMPLE_DIR/scripts/start.sh" >/dev/null
assert_contains "$(cat "$COMMAND_LOG")" \
  "args=billing-integrity recover" \
  "start did not use the sandbox-scoped recover command"

: >"$COMMAND_LOG"
FAKE_SANDBOX_EXISTS=1 bash "$EXAMPLE_DIR/scripts/stop.sh" >/dev/null
assert_contains "$(cat "$COMMAND_LOG")" "args=tunnel stop" \
  "stop did not stop the gateway through tunnel stop"

: >"$COMMAND_LOG"
FAKE_SANDBOX_EXISTS=1 bash "$EXAMPLE_DIR/scripts/install.sh" >/dev/null
assert_contains "$(cat "$COMMAND_LOG")" \
  "args=billing-integrity skill install $EXAMPLE_DIR/skills/provider-billing-integrity" \
  "install did not deploy the skill"
if grep -q 'policy-add' "$COMMAND_LOG"; then
  fail "install applied a network policy; v1 is offline"
fi

echo "ok"
