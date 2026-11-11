# ==============================================================================
# Multi-arch Dockerfile for Mutable Instruments firmware development
# Supports both:
#   - linux/amd64 (x86_64)
#   - linux/arm64 (Apple Silicon M1/M2/M3/M4, Raspberry Pi 4/5, Manjaro ARM)
# ==============================================================================

FROM ubuntu:20.04

ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive
ENV LANGUAGE=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Base development tools common to both architectures
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
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Architecture-specific toolchain setup
RUN if [ "$TARGETARCH" = "amd64" ]; then \
        dpkg --add-architecture i386 && \
        apt-get update && \
        apt-get install -y --no-install-recommends libc6:i386 libstdc++6:i386 libncurses5:i386 && \
        apt-get clean && rm -rf /var/lib/apt/lists/* && \
        wget -nv https://launchpadlibrarian.net/160488069/gcc-arm-none-eabi-4_8-2013q4-20131204-linux.tar.bz2 -O /tmp/arm.tar.bz2 && \
        tar -xjf /tmp/arm.tar.bz2 -C /usr/local/ && \
        mv /usr/local/gcc-arm-none-eabi-4_8-2013q4 /usr/local/arm-4.8.3 && \
        ln -sfn /usr/local/arm-4.8.3 /usr/local/arm && \
        rm /tmp/arm.tar.bz2 ; \
    else \
        # On ARM64 (Apple Silicon / Manjaro ARM), install native gcc-arm-none-eabi
        apt-get update && \
        apt-get install -y --no-install-recommends gcc-arm-none-eabi libnewlib-arm-none-eabi && \
        apt-get clean && rm -rf /var/lib/apt/lists/* && \
        mkdir -p /usr/local/arm-4.8.3/bin && \
        for tool in gcc g++ as ld objcopy objdump size nm ar ranlib; do \
            if [ -f "/usr/bin/arm-none-eabi-${tool}" ]; then \
                ln -sf "/usr/bin/arm-none-eabi-${tool}" "/usr/local/arm-4.8.3/bin/arm-none-eabi-${tool}"; \
            fi; \
        done && \
        ln -sfn /usr/local/arm-4.8.3 /usr/local/arm ; \
    fi

ENV PATH="/usr/local/arm-4.8.3/bin:${PATH}"
ENV PYTHONPATH=".:${PYTHONPATH}"

# Flags to ensure modern compilers on ARM64 don't abort on legacy warnings
ENV CFLAGS="-Wno-error -fcommon"
ENV CXXFLAGS="-Wno-error -fcommon"

WORKDIR /workspace/eurorack

CMD ["/bin/bash"]
