#!/usr/bin/env bash
# ==============================================================================
# Mutable Instruments Development Environment - Ubuntu 20.04 / 22.04 LTS Setup
# ==============================================================================

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends \
    locales \
    build-essential \
    pkg-config \
    git \
    wget \
    curl \
    bzip2 \
    cowsay \
    figlet \
    libusb-1.0-0-dev \
    libftdi1-dev \
    openocd \
    stlink-tools \
    gcc-avr \
    binutils-avr \
    avr-libc \
    avrdude

sudo locale-gen en_US.UTF-8 || true

# Install 32-bit compatibility libraries for GCC ARM 4.8.3
sudo dpkg --add-architecture i386
sudo apt-get update -qq
sudo apt-get install -y libc6:i386 libstdc++6:i386 libncurses5:i386 || {
    # On Ubuntu 24.04+ where libncurses5:i386 is gone, install libncurses6:i386 and symlink
    sudo apt-get install -y libc6:i386 libstdc++6:i386 libncurses6:i386 || true
    if [ ! -e /usr/lib/i386-linux-gnu/libncurses.so.5 ] && [ -e /usr/lib/i386-linux-gnu/libncurses.so.6 ]; then
        sudo ln -sf /usr/lib/i386-linux-gnu/libncurses.so.6 /usr/lib/i386-linux-gnu/libncurses.so.5
    fi
}

# Install GCC ARM 4.8.3
ARM_TAR="gcc-arm-none-eabi-4_8-2013q4-20131204-linux.tar.bz2"
ARM_URL="https://launchpadlibrarian.net/160488069/${ARM_TAR}"

if [ ! -d "/usr/local/arm-4.8.3" ]; then
    cd /tmp
    wget -nv "${ARM_URL}"
    tar -xjf "${ARM_TAR}"
    sudo rm -rf /usr/local/arm-4.8.3
    sudo mv gcc-arm-none-eabi-4_8-2013q4 /usr/local/arm-4.8.3
    rm -f "${ARM_TAR}"
fi

sudo ln -sfn /usr/local/arm-4.8.3 /usr/local/arm
sudo ln -sfn /usr /usr/local/CrossPack-AVR

# Install isolated Python 2.7 environment
if [ ! -d "/opt/miniconda2" ]; then
    cd /tmp
    wget -nv https://repo.anaconda.com/miniconda/Miniconda2-latest-Linux-x86_64.sh -O miniconda2.sh
    sudo bash miniconda2.sh -b -p /opt/miniconda2
    rm -f miniconda2.sh
    sudo /opt/miniconda2/bin/conda install -y -q numpy scipy matplotlib || true
fi

# Programmer udev rules
sudo tee /etc/udev/rules.d/99-mutable-dev.rules > /dev/null << 'EOF'
SUBSYSTEMS=="usb", ATTRS{idVendor}=="15ba", ATTRS{idProduct}=="0003", GROUP="users", MODE="0666"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="15ba", ATTRS{idProduct}=="002a", GROUP="users", MODE="0666"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="15ba", ATTRS{idProduct}=="002b", GROUP="users", MODE="0666"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="2104", GROUP="users", MODE="0666"
SUBSYSTEMS=="usb", KERNEL=="ttyUSB*", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", GROUP="users", MODE="0666", SYMLINK+="ftdi-usbserial"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="3744", GROUP="users", MODE="0666"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="3748", GROUP="users", MODE="0666"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="374b", GROUP="users", MODE="0666"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="3752", GROUP="users", MODE="0666"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="374d", GROUP="users", MODE="0666"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="374e", GROUP="users", MODE="0666"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="374f", GROUP="users", MODE="0666"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="3753", GROUP="users", MODE="0666"
EOF

sudo udevadm control --reload-rules || true
sudo udevadm trigger || true

sudo tee /etc/profile.d/mutable-dev.sh > /dev/null << 'EOF'
export PATH="/opt/miniconda2/bin:/usr/local/arm-4.8.3/bin:$PATH"
export PYTHONPATH=".:$PYTHONPATH"
export LC_ALL="en_US.UTF-8"
export LANGUAGE="en_US.UTF-8"
EOF

if [ -f "/home/vagrant/.bashrc" ]; then
    if ! grep -q "mutable-dev.sh" "/home/vagrant/.bashrc"; then
        echo 'source /etc/profile.d/mutable-dev.sh' >> "/home/vagrant/.bashrc"
    fi
fi

