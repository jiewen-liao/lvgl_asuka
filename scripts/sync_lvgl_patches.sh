#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

git -C "${ROOT_DIR}" submodule update --init --recursive
"${SCRIPT_DIR}/apply_lvgl_patches.sh"
