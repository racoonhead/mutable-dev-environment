#!/usr/bin/env bash
# Usage:
#   ./docker-build.sh clouds              (builds clouds firmware)
#   ./docker-build.sh clouds hex          (builds hex)
#   ./docker-build.sh clouds wav          (builds wav bootloader file)
#   ./docker-build.sh bash                (starts interactive bash shell)

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR"

if [ ! "$(docker images -q mutable-dev:latest 2> /dev/null)" ]; then
    echo "Building Mutable Instruments docker image..."
    docker compose build
fi

if [ $# -eq 0 ]; then
    echo "Starting interactive build container..."
    docker compose run --rm mutable-builder bash
elif [ "$1" == "bash" ] || [ "$1" == "sh" ]; then
    docker compose run --rm mutable-builder "$1"
else
    MODULE=$1
    shift
    TARGET=${1:-""}
    echo "Compiling $MODULE $TARGET..."
    docker compose run --rm mutable-builder make -f "${MODULE}/makefile" $TARGET
fi

