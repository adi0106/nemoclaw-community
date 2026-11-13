#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Install the skill (with its synthetic data and CPU tools) into an onboarded
# sandbox. The v1 workflow is offline, so no network policy is applied; the
# optional hosted-model policy in policies-optional/ is never applied here.
# Re-run after changing the skill.

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

echo "Installing provider-billing-integrity into sandbox '$NEMOCLAW_SANDBOX_NAME'"
run nemoclaw "$NEMOCLAW_SANDBOX_NAME" skill install \
  "$EXAMPLE_DIR/skills/provider-billing-integrity"

echo
echo "Installed. Ensure the sandbox is running with: bash scripts/start.sh"
