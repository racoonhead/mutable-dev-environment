@echo off
rem Usage:
rem   docker-build.bat clouds
rem   docker-build.bat clouds hex
rem   docker-build.bat clouds wav
rem   docker-build.bat bash

cd /d "%~dp0"

if not exist "..\eurorack\.git" (
    echo Cloning https://github.com/racoonhead/eurorack.git...
    git clone --recurse-submodules https://github.com/racoonhead/eurorack.git ..\eurorack
)

docker image inspect mutable-dev:latest >nul 2>&1
if errorlevel 1 (
    echo Building Mutable Instruments docker image...
    docker compose build
)

if "%~1"=="" (
    echo Starting interactive build container...
    docker compose run --rm mutable-builder bash
) else if "%~1"=="bash" (
    docker compose run --rm mutable-builder bash
) else (
    echo Compiling %1 %2...
    docker compose run --rm mutable-builder make -f %1/makefile %2
)

