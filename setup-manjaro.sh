#!/usr/bin/env bash
# ==============================================================================
# Mutable Instruments Development Environment - Manjaro / Arch Linux Setup
# Supports both:
#   - aarch64 / arm64 (Raspberry Pi 4/5, Apple Silicon VMs, Manjaro ARM)
#   - x86_64          (Intel / AMD 64-bit)
# ==============================================================================

set -euo pipefail

ARCH="$(uname -m)"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
REAL_USER="${SUDO_USER:-$(id -un)}"
REAL_GROUP="$(id -gn "${REAL_USER}" 2>/dev/null || echo "${REAL_USER}")"
REAL_HOME="$(getent passwd "${REAL_USER}" | cut -d: -f6 2>/dev/null || echo "${HOME}")"

echo "======================================================================"
echo " Mutable Instruments Development Environment Setup (Manjaro / Arch)"
echo " Architecture : ${ARCH}"
echo " Target User  : ${REAL_USER} (${REAL_HOME})"
echo "======================================================================"

# Ensure all shell scripts in this directory are executable
chmod +x "${SCRIPT_DIR}"/*.sh 2>/dev/null || true

# ------------------------------------------------------------------------------
# 1. System Packages & Toolchain Dependencies
# ------------------------------------------------------------------------------
echo "==> [1/6] Installing system packages and hardware programmer tools..."

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
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        echo "Enabling [multilib] repository in /etc/pacman.conf..."
        sudo sed -i '/\[multilib\]/,/Include/ s/^#//' /etc/pacman.conf
    fi

    sudo pacman -Sy --needed --noconfirm \
        "${BASE_PKGS[@]}" \
        lib32-glibc \
        lib32-gcc-libs \
        lib32-ncurses \
        ncurses \
        python \
        python-numpy \
        python-scipy

    # Compatibility symlinks for libncurses.so.5 required by GCC 4.8.3 (32-bit)
    if [ ! -e /usr/lib32/libncurses.so.5 ]; then
        if [ -e /usr/lib32/libncursesw.so.6 ]; then
            sudo ln -sf /usr/lib32/libncursesw.so.6 /usr/lib32/libncurses.so.5
        elif [ -e /usr/lib32/libncurses.so.6 ]; then
            sudo ln -sf /usr/lib32/libncurses.so.6 /usr/lib32/libncurses.so.5
        fi
    fi
    if [ ! -e /usr/lib/libncurses.so.5 ] && [ -e /usr/lib/libncursesw.so.6 ]; then
        sudo ln -sf /usr/lib/libncursesw.so.6 /usr/lib/libncurses.so.5
    fi

elif [ "${ARCH}" = "aarch64" ] || [ "${ARCH}" = "arm64" ]; then
    sudo pacman -Sy --needed --noconfirm \
        "${BASE_PKGS[@]}" \
        arm-none-eabi-gcc \
        arm-none-eabi-binutils \
        arm-none-eabi-newlib \
        python \
        python-numpy \
        python-scipy
else
    echo "ERROR: Unsupported architecture: ${ARCH}"
    exit 1
fi

# ------------------------------------------------------------------------------
# 2. GCC ARM Embedded Toolchain Configuration
# ------------------------------------------------------------------------------
echo "==> [2/6] Configuring GCC ARM Embedded toolchain..."

if [ "${ARCH}" = "x86_64" ]; then
    ARM_TAR="gcc-arm-none-eabi-4_8-2013q4-20131204-linux.tar.bz2"
    ARM_URL="https://launchpadlibrarian.net/160488069/${ARM_TAR}"

    if [ ! -d "/usr/local/arm-4.8.3/bin" ]; then
        cd /tmp
        [ -f "${ARM_TAR}" ] || wget -nv "${ARM_URL}"
        tar -xjf "${ARM_TAR}"
        sudo rm -rf /usr/local/arm-4.8.3
        sudo mv gcc-arm-none-eabi-4_8-2013q4 /usr/local/arm-4.8.3
        rm -f "${ARM_TAR}"
    fi

elif [ "${ARCH}" = "aarch64" ] || [ "${ARCH}" = "arm64" ]; then
    # Map native AArch64 arm-none-eabi toolchain to /usr/local/arm-4.8.3/bin
    sudo mkdir -p /usr/local/arm-4.8.3/bin

    # Create compiler wrappers for gcc/g++ that append -Wno-error -fcommon
    # so hardcoded -Werror in stmlib/makefile.inc does not halt builds on modern GCC
    sudo tee /usr/local/arm-4.8.3/bin/arm-none-eabi-gcc > /dev/null << 'EOF'
#!/usr/bin/env bash
exec /usr/bin/arm-none-eabi-gcc "$@" -Wno-error -fcommon
EOF

    sudo tee /usr/local/arm-4.8.3/bin/arm-none-eabi-g++ > /dev/null << 'EOF'
#!/usr/bin/env bash
exec /usr/bin/arm-none-eabi-g++ "$@" -Wno-error -fcommon
EOF

    sudo chmod 755 /usr/local/arm-4.8.3/bin/arm-none-eabi-gcc /usr/local/arm-4.8.3/bin/arm-none-eabi-g++

    for tool in as ld objcopy objdump size nm ar ranlib gdb strip readelf; do
        if [ -f "/usr/bin/arm-none-eabi-${tool}" ]; then
            sudo ln -sf "/usr/bin/arm-none-eabi-${tool}" "/usr/local/arm-4.8.3/bin/arm-none-eabi-${tool}"
        fi
    done
fi

sudo ln -sfn /usr/local/arm-4.8.3 /usr/local/arm
sudo ln -sfn /usr /usr/local/CrossPack-AVR
sudo chmod -R a+rX /usr/local/arm-4.8.3

# Ensure OpenOCD scripts are reachable at the default path expected by stmlib
if [ -d "/usr/share/openocd/scripts" ]; then
    sudo mkdir -p /opt/local/share/openocd
    sudo ln -sfn /usr/share/openocd/scripts /opt/local/share/openocd/scripts
fi

# ------------------------------------------------------------------------------
# 3. Python Environment Setup
# ------------------------------------------------------------------------------
echo "==> [3/6] Configuring Python environment..."

if [ "${ARCH}" = "x86_64" ]; then
    if [ ! -d "/opt/miniconda2" ]; then
        cd /tmp
        wget -nv https://repo.anaconda.com/miniconda/Miniconda2-latest-Linux-x86_64.sh -O miniconda2.sh
        sudo bash miniconda2.sh -b -p /opt/miniconda2
        rm -f miniconda2.sh
        sudo /opt/miniconda2/bin/conda install -y -q numpy scipy matplotlib || true
        sudo chmod -R a+rX /opt/miniconda2
    fi
fi

# ------------------------------------------------------------------------------
# 4. USB Programmer udev Rules (ST-Link V1/V2/V3, Olimex, AVRISP, FTDI)
# ------------------------------------------------------------------------------
echo "==> [4/6] Installing USB programmer udev rules..."

sudo tee /etc/udev/rules.d/99-mutable-dev.rules > /dev/null << 'EOF'
# Olimex OpenOCD JTAG adapters
SUBSYSTEMS=="usb", ATTRS{idVendor}=="15ba", ATTRS{idProduct}=="0003", GROUP="users", MODE="0666"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="15ba", ATTRS{idProduct}=="002a", GROUP="users", MODE="0666"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="15ba", ATTRS{idProduct}=="002b", GROUP="users", MODE="0666"

# Atmel AVRISP mkII
SUBSYSTEMS=="usb", ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="2104", GROUP="users", MODE="0666"

# FTDI USB-Serial adapter
SUBSYSTEMS=="usb", KERNEL=="ttyUSB*", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", GROUP="users", MODE="0666", SYMLINK+="ftdi-usbserial"

# ST-Link V1 / V2 / V2-1 / V3
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="3744", GROUP="users", MODE="0666"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="3748", GROUP="users", MODE="0666"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="374b", GROUP="users", MODE="0666"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="3752", GROUP="users", MODE="0666"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="374d", GROUP="users", MODE="0666"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="374e", GROUP="users", MODE="0666"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="374f", GROUP="users", MODE="0666"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="3753", GROUP="users", MODE="0666"
EOF

sudo chmod 644 /etc/udev/rules.d/99-mutable-dev.rules
if command -v udevadm >/dev/null 2>&1; then
    sudo udevadm control --reload-rules || true
    sudo udevadm trigger || true
fi

if [ -n "${REAL_USER}" ] && [ "${REAL_USER}" != "root" ]; then
    sudo usermod -a -G uucp,users "${REAL_USER}" 2>/dev/null || true
fi

# ------------------------------------------------------------------------------
# 5. Environment Profile Configuration
# ------------------------------------------------------------------------------
echo "==> [5/6] Configuring shell environment profile..."

if [ "${ARCH}" = "x86_64" ] && [ -d "/opt/miniconda2/bin" ]; then
    EXTRA_PATH="/opt/miniconda2/bin:/usr/local/arm-4.8.3/bin"
else
    EXTRA_PATH="/usr/local/arm-4.8.3/bin"
fi

sudo tee /etc/profile.d/mutable-dev.sh > /dev/null << EOF
export PATH="${EXTRA_PATH}:\${PATH}"
export PYTHONPATH=".:\${PYTHONPATH:-}"
export OPENOCD_SCRIPT_PATH="/usr/share/openocd/scripts/"
export LC_ALL="en_US.UTF-8"
export LANGUAGE="en_US.UTF-8"
EOF

sudo chmod 755 /etc/profile.d/mutable-dev.sh

for rc_file in "${REAL_HOME}/.bashrc" "/home/vagrant/.bashrc"; do
    if [ -f "${rc_file}" ] && ! grep -q "/etc/profile.d/mutable-dev.sh" "${rc_file}"; then
        echo '[ -f /etc/profile.d/mutable-dev.sh ] && source /etc/profile.d/mutable-dev.sh' >> "${rc_file}"
    fi
done

# ------------------------------------------------------------------------------
# 6. Clone or Update Source Repository (https://github.com/racoonhead/eurorack.git)
# ------------------------------------------------------------------------------
if [ -f "${SCRIPT_DIR}/1_clone-code.sh" ]; then
    echo "==> [6/6] Syncing source repository (https://github.com/racoonhead/eurorack.git)..."
    if [ "$(id -u)" -eq 0 ] && [ "${REAL_USER}" != "root" ]; then
        sudo -u "${REAL_USER}" bash "${SCRIPT_DIR}/1_clone-code.sh" "${USER_GITHUB_URL:-https://github.com/racoonhead/eurorack.git}"
    else
        bash "${SCRIPT_DIR}/1_clone-code.sh" "${USER_GITHUB_URL:-https://github.com/racoonhead/eurorack.git}"
    fi
fi

# Guarantee proper user ownership of workspace directories (prevents Permission denied)
WORKSPACE_DIR="$( dirname "${SCRIPT_DIR}" )"
if [ -n "${REAL_USER}" ] && [ "${REAL_USER}" != "root" ]; then
    sudo chown -R "${REAL_USER}:${REAL_GROUP}" "${SCRIPT_DIR}" 2>/dev/null || true
    if [ -d "${WORKSPACE_DIR}/eurorack" ]; then
        sudo chown -R "${REAL_USER}:${REAL_GROUP}" "${WORKSPACE_DIR}/eurorack" 2>/dev/null || true
    fi
fi

echo "======================================================================"
echo " Toolchain Verification:"
/usr/local/arm-4.8.3/bin/arm-none-eabi-gcc --version | head -n 1 || echo "ARM GCC: ERROR"
avr-gcc --version | head -n 1 || echo "AVR GCC: ERROR"
openocd --version 2>&1 | head -n 1 || echo "OpenOCD: ERROR"
echo "======================================================================"
echo " Setup complete! Run:"
echo "   source /etc/profile.d/mutable-dev.sh"
echo "   cd ../eurorack && make -j4 -f elements/makefile"
echo "======================================================================"
