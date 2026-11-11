#!/usr/bin/env bash

set -euo pipefail

# Determine target root directory:
# If running inside Vagrant and /vagrant/workspace exists, use it;
# otherwise use the parent directory of mutable-dev-environment.
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

if [ -d "$DEV_ENV/.git" ]; then
    echo "==> Repository already exists at ${DEV_ENV}, pulling latest changes..."
    cd "$DEV_ENV"
    git pull --ff-only || true
    git submodule update --init --recursive
else
    echo "==> Cloning ${USER_GITHUB_URL} into ${DEV_ENV}..."
    cd "$CODE_ROOT"
    git clone "$USER_GITHUB_URL" "$WORKING_DIR_NAME"
    cd "$DEV_ENV"
    if [ "$USER_GITHUB_URL" != "$UPSTREAM_REPO" ]; then
        git remote add pichenettes "$UPSTREAM_REPO" 2>/dev/null || true
    fi
    git submodule update --init --recursive
fi

# Ensure stm_audio_bootloader has the latest STM32H7 support
if [ -d "$DEV_ENV/stm_audio_bootloader/.git" ] || [ -f "$DEV_ENV/stm_audio_bootloader/.git" ]; then
    echo "==> Updating stm_audio_bootloader submodule for STM32H7 support..."
    cd "$DEV_ENV/stm_audio_bootloader"
    git fetch origin master && git checkout origin/master || true
fi

# Automatically cd to code directory on login if not already configured
if [ -f "$HOME/.bashrc" ] && ! grep -q "cd $DEV_ENV" "$HOME/.bashrc"; then
    echo "cd $DEV_ENV" >> "$HOME/.bashrc"
fi
