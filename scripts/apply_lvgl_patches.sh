#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PATCH_FILE="${ROOT_DIR}/patches/lvgl-rga.patch"
LVGL_DIR="${ROOT_DIR}/lvgl"

if [[ ! -f "${PATCH_FILE}" ]]; then
    echo "Patch file not found: ${PATCH_FILE}" >&2
    exit 1
fi

if ! git -C "${LVGL_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "lvgl submodule is not initialized. Run: git submodule update --init --recursive" >&2
    exit 1
fi

if git -C "${LVGL_DIR}" apply --reverse --check "${PATCH_FILE}" >/dev/null 2>&1; then
    echo "Patch already applied."
    exit 0
fi

if ! git -C "${LVGL_DIR}" apply --check "${PATCH_FILE}"; then
    echo "Patch does not apply cleanly. Ensure lvgl submodule is at the expected version." >&2
    exit 1
fi

git -C "${LVGL_DIR}" apply "${PATCH_FILE}"
echo "Applied LVGL patches."
