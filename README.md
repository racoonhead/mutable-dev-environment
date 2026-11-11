# Mutable Instruments Development Environment

Development environment for compiling, modifying, and flashing firmware for Mutable Instruments Eurorack modules (including the **Elements v0.4** STM32H743 revision).

By default, all setup scripts automatically clone and synchronize the firmware repository from:
`https://github.com/racoonhead/eurorack.git`

---

## Supported Platforms & Architectures

* **ARM64 (`aarch64`):** Raspberry Pi 4 / 5 (Manjaro ARM / Arch Linux ARM), Apple Silicon (M1/M2/M3/M4 via VM or Docker), and other 64-bit ARM hosts.
  * Installs the native `arm-none-eabi-gcc` toolchain (with full **ARM Cortex-M7 / STM32H743** support required for *Elements v0.4* and *Beads*).
  * Automatically maps toolchain binaries to `/usr/local/arm-4.8.3/bin/` and wraps `gcc`/`g++` with `-Wno-error -fcommon` so all existing Mutable Instruments makefiles work out of the box without modification.
* **x86_64 (`amd64`):** Standard Intel/AMD Linux hosts (Manjaro, Arch, Ubuntu).
  * Installs 32-bit `multilib` runtime libraries, the legacy `gcc-arm-none-eabi-4_8-2013q4` toolchain, and an isolated Python 2.7 environment (`/opt/miniconda2`) with `numpy`, `scipy`, and `matplotlib`.

---

## Option A: Native Installation on Manjaro / Arch Linux (Recommended for Raspberry Pi 5 & Manjaro Hosts)

Run the automated setup script from the `mutable-dev-environment` directory:

```bash
cd mutable-dev-environment
chmod +x setup-manjaro.sh 1_clone-code.sh
./setup-manjaro.sh
```

> **Note:** Run `./setup-manjaro.sh` as your normal user (do not prefix with `sudo`; the script will prompt for `sudo` only when installing system packages). Even if invoked via `sudo`, the script automatically restores file ownership of `../eurorack` to your user account.

### What `setup-manjaro.sh` Configures:
1. Installs `base-devel`, `openocd`, `stlink`, `avr-gcc`, `avr-libc`, `avrdude`, `figlet`, `cowsay`, `python`, `python-numpy`, and `python-scipy`.
2. Configures the ARM cross-compiler in `/usr/local/arm-4.8.3/`, `/usr/local/arm-4.9/` (required by *Beads*), and `/usr/local/arm/`, AVR symlink in `/usr/local/CrossPack-AVR`, and OpenOCD scripts in `/opt/local/share/openocd/scripts`.
3. Installs USB `udev` rules (`/etc/udev/rules.d/99-mutable-dev.rules`) for ST-Link V1/V2/V2-1/V3, Olimex ARM-USB-OCD-H / TINY-H, Atmel AVRISP mkII, and FTDI serial adapters.
4. Writes `/etc/profile.d/mutable-dev.sh` and appends it to `~/.bashrc`.
5. Clones (or updates) `https://github.com/racoonhead/eurorack.git` into `../eurorack`, initializes all submodules (`stmlib`, `stm_audio_bootloader`, `avrlib`, `avrlibx`, `avr_audio_bootloader`), and checks out the latest `stm_audio_bootloader` with STM32H7 support.

After the script finishes, load the environment and move to the repository root:

```bash
source /etc/profile.d/mutable-dev.sh
cd ../eurorack
```

---

## Option B: Docker Environment (Linux, macOS, Windows)

Multi-architecture container (`linux/arm64` and `linux/amd64`) with all compilers, libraries, and Python dependencies pre-installed.

### On Linux / Manjaro / macOS:
```bash
chmod +x docker-build.sh

# Compile a specific module:
./docker-build.sh elements
./docker-build.sh clouds
./docker-build.sh plaits

# Compile a specific make target (hex, wav, clean, etc.):
./docker-build.sh elements hex
./docker-build.sh elements wav

# Open an interactive shell inside the container:
./docker-build.sh bash
```

### On Windows:
```cmd
docker-build.bat elements
docker-build.bat elements hex
docker-build.bat elements wav
docker-build.bat bash
```

---

## Option C: Vagrant & VirtualBox

For x86_64 machines running VirtualBox and Vagrant (defaults to `archlinux/archlinux`, or `generic/ubuntu2204` if `VAGRANT_BOX=generic/ubuntu2204` is set):

```bash
vagrant up
vagrant ssh
cd /vagrant/workspace/eurorack
```

---

## Detailed Command Reference

All `make` commands **must be executed from the root of the `eurorack` directory** (not from inside the module subdirectory):

```bash
cd ../eurorack
```

### 1. Compiling Module Firmware (`.bin` and `.elf`)

Use `-j4` (or `-j$(nproc)`) for parallel compilation across all CPU cores:

```bash
# Compile Elements (Revision v0.4 - STM32H743):
make -j4 -f elements/makefile

# Compile other STM32 modules:
make -j4 -f clouds/makefile
make -j4 -f plaits/makefile
make -j4 -f rings/makefile
make -j4 -f braids/makefile
make -j4 -f beads/makefile
make -j4 -f marbles/makefile
make -j4 -f stages/makefile
```

Compiled binaries are placed in `build/<module>/`:
* `build/elements/elements.bin`
* `build/elements/elements.elf`
* `build/elements/elements.map`

### 2. Building Intel HEX Files (`.hex`)

```bash
make -j4 -f elements/makefile hex
```
Output: `build/elements/elements.hex`

### 3. Compiling the Bootloader

```bash
make -j4 -f elements/bootloader/makefile
make -j4 -f elements/bootloader/makefile hex
```
Output: `build/elements_bootloader/elements_bootloader.bin` and `.hex`

### 4. Building Combined Bootloader + Application Image (`combo`)

To create a single image containing both the bootloader and the main firmware:

```bash
# Build bootloader first, then combo image:
make -j4 -f elements/bootloader/makefile
make -j4 -f elements/makefile combo_bin
make -j4 -f elements/makefile combo_hex
```
Output:
* `build/elements/elements_bootloader_combo.bin`
* `build/elements/elements_bootloader_combo.hex`

### 5. Generating Audio Bootloader Update Files (`.wav`)

Generates a QPSK-modulated `.wav` file for updating firmware via the module's audio input:

```bash
make -f elements/makefile wav
```
Output: `build/elements/elements.wav`

### 6. Regenerating Lookup Tables and Sample Resources (`resources`)

If you modify lookup tables, filter coefficients, or audio samples inside `<module>/resources/`:

```bash
touch elements/resources/resources.py
make -f elements/makefile resources
```

### 7. Cleaning Build Artifacts (`clean`)

Always run `clean` after changing makefile definitions or hardware headers:

```bash
make -f elements/makefile clean
```

---

## Flashing Firmware via Hardware Programmers (JTAG / SWD / ISP)

### Using ST-Link V2 / V2-1 / V3 (SWD)

Set `PGM_INTERFACE=stlink-v2` (and `PGM_INTERFACE_TYPE=hla` if required by your OpenOCD version):

```bash
# Flash application + bootloader combo via ST-Link:
PGM_INTERFACE=stlink-v2 make -f elements/makefile upload

# Flash application binary only (without erasing bootloader):
PGM_INTERFACE=stlink-v2 make -f elements/makefile upload_jtag_no_erase
```

You can also flash directly using `st-flash` (from the `stlink` package) or `openocd`:

```bash
# Direct flash using st-flash at application base address (0x08008000 or 0x08000000 for combo):
st-flash write build/elements/elements_bootloader_combo.bin 0x08000000
```

### Using Olimex ARM-USB-OCD-H or ARM-USB-TINY-H (JTAG)

```bash
# Olimex ARM-USB-OCD-H:
PGM_INTERFACE=ftdi/olimex-arm-usb-ocd-h make -f elements/makefile upload

# Olimex ARM-USB-TINY-H:
PGM_INTERFACE=ftdi/olimex-arm-usb-tiny-h make -f elements/makefile upload
```

### Flashing AVR Modules (Grids, Branches, Edges)

```bash
PROGRAMMER=avrispmkII make -f grids/makefile upload
```

---

## Troubleshooting

### 1. `Permission denied` when running `make` or scripts
If a previous command was run with `sudo`, some files in `eurorack/` or `build/` may be owned by `root`. Fix ownership and permissions with:

```bash
sudo chown -R $USER:$USER ../eurorack ../mutable-dev-environment
sudo chmod -R a+rX /usr/local/arm-4.8.3
chmod +x *.sh
```

### 2. `arm-none-eabi-gcc: command not found`
Ensure the environment profile is loaded in your current shell:

```bash
source /etc/profile.d/mutable-dev.sh
```

### 3. Compiler Version Notes (STM32H7 vs STM32F1/F4)
* **Elements v0.4 & Beads (STM32H743 / Cortex-M7):** Require **GCC 5 or newer** (such as the native `arm-none-eabi-gcc` installed on Manjaro ARM / Raspberry Pi 5). The legacy 2013 GCC 4.8.3 toolchain does **not** support `-mcpu=cortex-m7`.
* **Legacy STM32F1/F4 Modules (Clouds, Plaits, Rings, Braids):** Compile on both Manjaro ARM (with the automatic `-Wno-error -fcommon` wrapper) and x86_64 (using GCC 4.8.3).

### 4. USB Programmer Permission Error (`LIBUSB_ERROR_ACCESS`)
Reload `udev` rules and re-plug the programmer:

```bash
sudo udevadm control --reload-rules && sudo udevadm trigger
```
If you were just added to the `uucp` and `users` groups, log out and log back in for group membership to take effect.
