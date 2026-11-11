# ==============================================================================
# Multi-arch Dockerfile for Mutable Instruments firmware development
# Supports both:
#   - linux/amd64 (x86_64)
#   - linux/arm64 (Raspberry Pi 4/5, Apple Silicon M1/M2/M3/M4, Manjaro ARM)
# ==============================================================================

FROM ubuntu:20.04

ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive
ENV LANGUAGE=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        pkg-config \
        git \
        wget \
        curl \
        bzip2 \
        locales \
        cowsay \
        figlet \
        libusb-1.0-0-dev \
        libftdi1-dev \
        openocd \
        stlink-tools \
        gcc-avr \
        binutils-avr \
        avr-libc \
        avrdude \
        python2.7 \
        python-numpy \
        python-scipy \
        python3 && \
    locale-gen en_US.UTF-8 && \
    ln -sf /usr/bin/python2.7 /usr/bin/python && \
    ln -sfn /usr /usr/local/CrossPack-AVR && \
    mkdir -p /opt/local/share/openocd && \
    ln -sfn /usr/share/openocd/scripts /opt/local/share/openocd/scripts && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Architecture-specific ARM toolchain setup
RUN if [ "$TARGETARCH" = "amd64" ]; then \
        dpkg --add-architecture i386 && \
        apt-get update && \
        apt-get install -y --no-install-recommends libc6:i386 libstdc++6:i386 libncurses5:i386 && \
        apt-get clean && rm -rf /var/lib/apt/lists/* && \
        wget -nv https://launchpadlibrarian.net/160488069/gcc-arm-none-eabi-4_8-2013q4-20131204-linux.tar.bz2 -O /tmp/arm.tar.bz2 && \
        tar -xjf /tmp/arm.tar.bz2 -C /usr/local/ && \
        mv /usr/local/gcc-arm-none-eabi-4_8-2013q4 /usr/local/arm-4.8.3 && \
        ln -sfn /usr/local/arm-4.8.3 /usr/local/arm && \
        chmod -R a+rX /usr/local/arm-4.8.3 && \
        rm /tmp/arm.tar.bz2 ; \
    else \
        apt-get update && \
        apt-get install -y --no-install-recommends gcc-arm-none-eabi libnewlib-arm-none-eabi && \
        apt-get clean && rm -rf /var/lib/apt/lists/* && \
        mkdir -p /usr/local/arm-4.8.3/bin && \
        printf '#!/usr/bin/env bash\nexec /usr/bin/arm-none-eabi-gcc "$@" -Wno-error -fcommon\n' > /usr/local/arm-4.8.3/bin/arm-none-eabi-gcc && \
        printf '#!/usr/bin/env bash\nexec /usr/bin/arm-none-eabi-g++ "$@" -Wno-error -fcommon\n' > /usr/local/arm-4.8.3/bin/arm-none-eabi-g++ && \
        chmod 755 /usr/local/arm-4.8.3/bin/arm-none-eabi-gcc /usr/local/arm-4.8.3/bin/arm-none-eabi-g++ && \
        for tool in as ld objcopy objdump size nm ar ranlib gdb strip readelf; do \
            if [ -f "/usr/bin/arm-none-eabi-${tool}" ]; then \
                ln -sf "/usr/bin/arm-none-eabi-${tool}" "/usr/local/arm-4.8.3/bin/arm-none-eabi-${tool}"; \
            fi; \
        done && \
        ln -sfn /usr/local/arm-4.8.3 /usr/local/arm ; \
    fi

ENV PATH="/usr/local/arm-4.8.3/bin:${PATH}"
ENV PYTHONPATH=".:${PYTHONPATH}"
ENV OPENOCD_SCRIPT_PATH="/usr/share/openocd/scripts/"

WORKDIR /workspace/eurorack

CMD ["/bin/bash"]
