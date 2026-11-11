#!/usr/bin/env bash
# ==============================================================================
# Mutable Instruments Development Environment - Manjaro / Arch Linux Setup
# Supports both:
#   - x86_64  (Intel / AMD 64-bit)
#   - aarch64 (ARM 64-bit / Manjaro ARM on Apple Silicon, Raspberry Pi 4/5, etc.)
# ==============================================================================

set -euo pipefail

ARCH=$(uname -m)
echo "======================================================================"
echo " Setting up Mutable Instruments Development Environment on Manjaro"
echo " Detected Architecture: ${ARCH}"
echo "======================================================================"

# ------------------------------------------------------------------------------
# 1. Base tools and packages
# ------------------------------------------------------------------------------
echo "==> [1/5] Installing base packages and programmers..."

BASE_PKGS=(
    base-devel
    git
    wget
    curl
    pkgconf
    cowsay
    figlet
    openocd
    stlink
    avr-gcc
    avr-binutils
    avr-libc
    avrdude
    libusb
    libftdi
)

if [ "${ARCH}" = "x86_64" ]; then
    echo "Configuring x86_64 multilib..."
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        echo "Enabling [multilib] repository in /etc/pacman.conf..."
        sudo sed -i '/\[multilib\]/,/Include/ s/^#//' /etc/pacman.conf
    fi

    sudo pacman -Sy --needed --noconfirm \
        "${BASE_PKGS[@]}" \
        lib32-glibc \
        lib32-gcc-libs \
        lib32-ncurses \
        ncurses

    # Compatibility symlink for libncurses.so.5 required by Launchpad GCC 4.8.3
    if [ ! -e /usr/lib32/libncurses.so.5 ]; then
        if [ -e /usr/lib32/libncursesw.so.6 ]; then
            sudo ln -sf /usr/lib32/libncursesw.so.6 /usr/lib32/libncurses.so.5
        elif [ -e /usr/lib32/libncurses.so.6 ]; then
            sudo ln -sf /usr/lib32/libncurses.so.6 /usr/lib32/libncurses.so.5
        fi
    fi
    if [ ! -e /usr/lib/libncurses.so.5 ]; then
        if [ -e /usr/lib/libncursesw.so.6 ]; then
            sudo ln -sf /usr/lib/libncursesw.so.6 /usr/lib/libncurses.so.5
        fi
    fi

elif [ "${ARCH}" = "aarch64" ] || [ "${ARCH}" = "arm64" ]; then
    echo "Installing native AArch64 (ARM 64-bit) packages..."
    sudo pacman -Sy --needed --noconfirm \
        "${BASE_PKGS[@]}" \
        arm-none-eabi-gcc \
        arm-none-eabi-binutils \
        arm-none-eabi-newlib \
        python \
        python-numpy \
        python-scipy
fi

# ------------------------------------------------------------------------------
# 2. GCC ARM Embedded Toolchain setup
# ------------------------------------------------------------------------------
echo "==> [2/5] Configuring GCC ARM Embedded Toolchain..."

if [ "${ARCH}" = "x86_64" ]; then
    # On x86_64, download the exact 4.8.3 toolchain
    ARM_TAR="gcc-arm-none-eabi-4_8-2013q4-20131204-linux.tar.bz2"
    ARM_URL="https://launchpadlibrarian.net/160488069/${ARM_TAR}"

    if [ ! -d "/usr/local/arm-4.8.3" ]; then
        cd /tmp
        if [ ! -f "${ARM_TAR}" ]; then
            wget -nv "${ARM_URL}"
        fi
        tar -xjf "${ARM_TAR}"
        sudo rm -rf /usr/local/arm-4.8.3
        sudo mv gcc-arm-none-eabi-4_8-2013q4 /usr/local/arm-4.8.3
        rm -f "${ARM_TAR}"
    fi

elif [ "${ARCH}" = "aarch64" ] || [ "${ARCH}" = "arm64" ]; then
    # On ARM CPU, the Launchpad x86 binary cannot run natively.
    # We map the native AArch64 arm-none-eabi tools into /usr/local/arm-4.8.3/bin
    # so all Mutable Instruments makefiles find them without modification!
    sudo mkdir -p /usr/local/arm-4.8.3/bin
    for tool in gcc g++ as ld objcopy objdump size nm ar ranlib gdb; do
        if [ -f "/usr/bin/arm-none-eabi-${tool}" ]; then
            sudo ln -sf "/usr/bin/arm-none-eabi-${tool}" "/usr/local/arm-4.8.3/bin/arm-none-eabi-${tool}"
        fi
    done
fi

sudo ln -sfn /usr/local/arm-4.8.3 /usr/local/arm
sudo ln -sfn /usr /usr/local/CrossPack-AVR

# ------------------------------------------------------------------------------
# 3. Python Environment Setup
# ------------------------------------------------------------------------------
echo "==> [3/5] Setting up Python environment..."

if [ "${ARCH}" = "x86_64" ]; then
    # Miniconda2 standalone Python 2.7 for x86_64
    if [ ! -d "/opt/miniconda2" ]; then
        cd /tmp
        wget -nv https://repo.anaconda.com/miniconda/Miniconda2-latest-Linux-x86_64.sh -O miniconda2.sh
        sudo bash miniconda2.sh -b -p /opt/miniconda2
        rm -f miniconda2.sh
        sudo /opt/miniconda2/bin/conda install -y -q numpy scipy matplotlib || true
    fi
elif [ "${ARCH}" = "aarch64" ] || [ "${ARCH}" = "arm64" ]; then
    # On Manjaro ARM, check if python2 is available; if not, try installing via pamac/yay
    if ! command -v python2 >/dev/null 2>&1; then
        echo "Attempting to install python2 from AUR / binary cache..."
        if command -v pamac >/dev/null 2>&1; then
            pamac build --no-confirm python2-bin || pamac build --no-confirm python2 || true
        elif command -v yay >/dev/null 2>&1; then
            yay -S --noconfirm python2-bin || yay -S --noconfirm python2 || true
        fi
    fi

    # If python2 is installed, symlink into /usr/local/bin if python is needed
    if command -v python2 >/dev/null 2>&1; then
        echo "python2 found on system."
    else
        echo "NOTE: python2 not found in official repo. Python 3 with numpy is installed."
        echo "If you need Python 2 for audio bootloader wav generation, run: pamac build python2"
    fi
fi

# ------------------------------------------------------------------------------
# 4. USB udev rules for ST-Link, Olimex JTAG, AVRISP, and FTDI
# ------------------------------------------------------------------------------
echo "==> [4/5] Installing USB udev rules..."
sudo tee /etc/udev/rules.d/99-mutable-dev.rules > /dev/null << 'EOF'
# Olimex OpenOCD JTAG
SUBSYSTEMS=="usb", ATTRS{idVendor}=="15ba", ATTRS{idProduct}=="0003", GROUP="users", MODE="0666"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="15ba", ATTRS{idProduct}=="002a", GROUP="users", MODE="0666"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="15ba", ATTRS{idProduct}=="002b", GROUP="users", MODE="0666"

# Atmel AVRISP mkII
SUBSYSTEMS=="usb", ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="2104", GROUP="users", MODE="0666"

# FTDI serial adapter
SUBSYSTEMS=="usb", KERNEL=="ttyUSB*", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", GROUP="users", MODE="0666", SYMLINK+="ftdi-usbserial"

# ST-Link V1
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="3744", GROUP="users", MODE="0666"

# ST-Link V2
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="3748", GROUP="users", MODE="0666"

# ST-Link V2-1
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="374b", GROUP="users", MODE="0666"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="3752", GROUP="users", MODE="0666"

# ST-Link V3
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="374d", GROUP="users", MODE="0666"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="374e", GROUP="users", MODE="0666"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="374f", GROUP="users", MODE="0666"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="3753", GROUP="users", MODE="0666"
EOF

if command -v udevadm >/dev/null 2>&1; then
    sudo udevadm control --reload-rules || true
    sudo udevadm trigger || true
fi

CURRENT_USER="${SUDO_USER:-$USER}"
if [ -n "$CURRENT_USER" ] && [ "$CURRENT_USER" != "root" ]; then
    sudo usermod -a -G uucp,users "$CURRENT_USER" || true
fi

# ------------------------------------------------------------------------------
# 5. Environment configuration
# ------------------------------------------------------------------------------
echo "==> [5/5] Configuring environment profile..."

if [ "${ARCH}" = "x86_64" ]; then
    EXTRA_PATH="/opt/miniconda2/bin:/usr/local/arm-4.8.3/bin"
else
    EXTRA_PATH="/usr/local/arm-4.8.3/bin"
fi

sudo tee /etc/profile.d/mutable-dev.sh > /dev/null << EOF
export PATH="${EXTRA_PATH}:\$PATH"
export PYTHONPATH=".:\$PYTHONPATH"
export LC_ALL="en_US.UTF-8"
export LANGUAGE="en_US.UTF-8"
EOF

# Ensure makefile doesn't abort on modern GCC warnings on AArch64
if [ "${ARCH}" = "aarch64" ] || [ "${ARCH}" = "arm64" ]; then
    echo 'export CFLAGS="-Wno-error -fcommon $CFLAGS"' | sudo tee -a /etc/profile.d/mutable-dev.sh > /dev/null
    echo 'export CXXFLAGS="-Wno-error -fcommon $CXXFLAGS"' | sudo tee -a /etc/profile.d/mutable-dev.sh > /dev/null
fi

if [ -f "$HOME/.bashrc" ]; then
    if ! grep -q "mutable-dev.sh" "$HOME/.bashrc"; then
        echo 'source /etc/profile.d/mutable-dev.sh' >> "$HOME/.bashrc"
    fi
fi

if [ -d "/home/vagrant" ] && [ -f "/home/vagrant/.bashrc" ]; then
    if ! grep -q "mutable-dev.sh" "/home/vagrant/.bashrc"; then
        echo 'source /etc/profile.d/mutable-dev.sh' >> "/home/vagrant/.bashrc"
    fi
fi

echo "======================================================================"
echo " Verification:"
/usr/local/arm-4.8.3/bin/arm-none-eabi-gcc --version | head -n 1 || echo "ARM GCC: ERROR"
avr-gcc --version | head -n 1 || echo "AVR GCC: ERROR"
openocd --version 2>&1 | head -n 1 || echo "OpenOCD: ERROR"
echo "======================================================================"
echo " Setup complete for ${ARCH} on Manjaro Linux!"
