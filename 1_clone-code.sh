#!/usr/bin/env bash
# ==============================================================================
# Clone and configure the Eurorack firmware repository and submodules
# Default repository: https://github.com/racoonhead/eurorack.git
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
if [ -d "/vagrant/workspace" ]; then
    CODE_ROOT="/vagrant/workspace"
elif [ -d "/vagrant" ]; then
    CODE_ROOT="/vagrant"
else
    CODE_ROOT="$( dirname "$SCRIPT_DIR" )"
fi

WORKING_DIR_NAME="eurorack"
DEV_ENV="${CODE_ROOT}/${WORKING_DIR_NAME}"

DEFAULT_REPO="https://github.com/racoonhead/eurorack.git"
UPSTREAM_REPO="https://github.com/pichenettes/eurorack.git"
USER_GITHUB_URL="${1:-$DEFAULT_REPO}"

if [ -d "${DEV_ENV}/.git" ]; then
    echo "==> Repository already exists at ${DEV_ENV}, updating..."
    cd "${DEV_ENV}"
    git pull --ff-only || true
    git submodule update --init --recursive
else
    echo "==> Cloning ${USER_GITHUB_URL} into ${DEV_ENV}..."
    mkdir -p "${CODE_ROOT}"
    cd "${CODE_ROOT}"
    git clone "${USER_GITHUB_URL}" "${WORKING_DIR_NAME}"
    cd "${DEV_ENV}"
    if [ "${USER_GITHUB_URL}" != "${UPSTREAM_REPO}" ]; then
        git remote add pichenettes "${UPSTREAM_REPO}" 2>/dev/null || true
    fi
    git submodule update --init --recursive
fi

# Ensure elements directory exists (symlink Elements_V0.4 -> elements if needed)
if [ ! -e "${DEV_ENV}/elements" ] && [ -d "${DEV_ENV}/Elements_V0.4" ]; then
    echo "==> Creating symlink elements -> Elements_V0.4..."
    ln -sfn Elements_V0.4 "${DEV_ENV}/elements"
fi

# Ensure stm_audio_bootloader has latest STM32H7 support
if [ -d "${DEV_ENV}/stm_audio_bootloader" ]; then
    echo "==> Updating stm_audio_bootloader submodule for STM32H7 support..."
    cd "${DEV_ENV}/stm_audio_bootloader"
    git fetch origin master 2>/dev/null && git checkout origin/master 2>/dev/null || true
fi

# Relax -Werror in stmlib/makefile.inc for modern GCC compatibility
if [ -f "${DEV_ENV}/stmlib/makefile.inc" ]; then
    sed -i 's/-Wall -Werror/-Wall -Wno-error -fcommon/g' "${DEV_ENV}/stmlib/makefile.inc" 2>/dev/null || true
fi

# Automatically navigate to the code directory on login
if [ -f "${HOME}/.bashrc" ] && ! grep -q "cd ${DEV_ENV}" "${HOME}/.bashrc"; then
    echo "cd ${DEV_ENV}" >> "${HOME}/.bashrc"
fi
