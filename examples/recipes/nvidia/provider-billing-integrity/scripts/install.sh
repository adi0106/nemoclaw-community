#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Install the skill (with its synthetic data and tools) into an onboarded
# sandbox. When the sandbox uses the build.nvidia.com provider, also enable
# hosted policy retrieval (Nemotron embed and rerank):
#   1. import the provider profile that binds a credential to ai.api.nvidia.com,
#   2. create or update a provider from the key in .env and attach it, and
#   3. apply the egress policy in policies/, and
#   4. restart the sandbox when a provider was newly attached: the running agent only
#      sees a new credential after its container restarts (the workspace is kept).
# The raw key stays in the OpenShell gateway; the sandbox holds placeholders.
# Without that provider the skill still works and reports retrieval as blocked.
# Re-run after changing the skill, policies, or key.

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$DIR/_lib.sh"

command -v nemoclaw >/dev/null || {
  echo "nemoclaw not in PATH — run scripts/onboard.sh first" >&2
  exit 1
}

if ! sandbox_exists "$NEMOCLAW_SANDBOX_NAME"; then
  echo "Sandbox '$NEMOCLAW_SANDBOX_NAME' not found — run scripts/onboard.sh first" >&2
  exit 1
fi

PROFILE_FILE="$EXAMPLE_DIR/providers/nvidia-ai-api.yaml"
PROFILE_ID="billing-integrity-nvidia-ai-api"
AI_PROVIDER="${NEMOCLAW_SANDBOX_NAME}-ai-api"
RESTART_NEEDED=0

enable_hosted_retrieval() {
  # Import the profile once. An existing profile is kept: changing it means
  # detaching and deleting the provider, then deleting the profile.
  if openshell provider profile export "$PROFILE_ID" >/dev/null 2>&1; then
    echo "Provider profile '$PROFILE_ID' already exists — keeping it."
  else
    run openshell provider profile import --file "$PROFILE_FILE"
  fi

  # The same build.nvidia.com key, under a second name, bound to ai.api.nvidia.com.
  export NVIDIA_AI_API_KEY="$NVIDIA_INFERENCE_API_KEY"
  if openshell provider get "$AI_PROVIDER" >/dev/null 2>&1; then
    run openshell provider update "$AI_PROVIDER" --credential NVIDIA_AI_API_KEY
  else
    run openshell provider create --name "$AI_PROVIDER" --type "$PROFILE_ID" \
      --credential NVIDIA_AI_API_KEY
  fi
  unset NVIDIA_AI_API_KEY

  if ! openshell sandbox provider list "$NEMOCLAW_SANDBOX_NAME" 2>/dev/null | grep -Fq "$AI_PROVIDER"; then
    run openshell sandbox provider attach "$NEMOCLAW_SANDBOX_NAME" "$AI_PROVIDER"
    RESTART_NEEDED=1
  fi

  run nemoclaw "$NEMOCLAW_SANDBOX_NAME" policy-add \
    --from-dir "$EXAMPLE_DIR/policies" \
    --yes
}

echo "Installing provider-billing-integrity into sandbox '$NEMOCLAW_SANDBOX_NAME'"
if [[ "${NEMOCLAW_PROVIDER:-build}" == "build" && -n "${NVIDIA_INFERENCE_API_KEY:-}" ]]; then
  command -v openshell >/dev/null || {
    echo "openshell not in PATH" >&2
    exit 1
  }
  echo "Enabling hosted policy retrieval (Nemotron embed and rerank)"
  enable_hosted_retrieval
else
  echo "note: hosted policy retrieval not enabled (needs NEMOCLAW_PROVIDER=build and" >&2
  echo "      NVIDIA_INFERENCE_API_KEY in .env). The skill will report it as blocked." >&2
fi

run nemoclaw "$NEMOCLAW_SANDBOX_NAME" skill install \
  "$EXAMPLE_DIR/skills/provider-billing-integrity"

if [[ "$RESTART_NEEDED" == "1" ]]; then
  echo "Restarting the sandbox so the agent picks up the new credential (workspace is kept)"
  run nemoclaw "$NEMOCLAW_SANDBOX_NAME" stop
  run nemoclaw "$NEMOCLAW_SANDBOX_NAME" start
fi

echo
echo "Installed. Ensure the sandbox is running with: bash scripts/start.sh"
