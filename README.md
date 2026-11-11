# Mutable Instruments Development Environment (Modernized)

Zmodernizované vývojové prostředí pro kompilaci a nahrávání firmwaru modulů **Mutable Instruments** (Clouds, Elements, Plaits, Rings, Braids, Marbles, Stages a AVR moduly jako Grids/Peaks/Branches).

Podporuje **x86_64** (Intel/AMD) i **ARM CPU / aarch64** (Manjaro ARM, Apple Silicon M1/M2/M3/M4, Raspberry Pi 4/5).

---

## Běh na ARM CPU (Manjaro ARM / Apple Silicon / Raspberry Pi)

Při běhu na procesorech ARM (architektura **aarch64**) nastává specifický problém:
Původní kompilátor `gcc-arm-none-eabi-4_8-2013q4` z Launchpadu byl zkompilován pro 32-bitový Intel x86. Na ARM procesoru nelze tento x86 binární soubor přímo spustit (`Exec format error`).

### Jak je to v novém prostředí vyřešeno:
1. **Skript `setup-manjaro.sh` automaticky detekuje architekturu (`uname -m`):**
   - Na **ARM64 (aarch64)** nainstaluje nativní balíček `arm-none-eabi-gcc` z repozitářů Manjaro ARM (který běží plnou nativní rychlostí vašeho procesoru).
   - Vytvoří mapovací symlinky do `/usr/local/arm-4.8.3/bin/`, takže původní makefily Mutable Instruments fungují bez jakékoliv ruční změny.
   - Automaticky přidá kompilátorové flagy `-Wno-error -fcommon`, aby novější GCC nezastavoval kompilaci na starých varováních.
2. **Multi-arch Docker:**
   - Dockerfile podporuje jak `linux/amd64`, tak `linux/arm64`.
   - Na Apple Silicon nebo Manjaro ARM se automaticky sestaví nativní ARM64 kontejner.
   - Pokud na Apple Silicon trváte na přesné binárce GCC 4.8.3, můžete kontejner spustit s emulací přes Rosettu: `docker compose run --platform linux/amd64 mutable-builder`.

---

## Varianta A: Nativní instalace v Manjaro ARM (nebo x86)

Ať už běžíte na fyzickém Manjaro ARM (např. Raspberry Pi 4/5, Pinebook) nebo ve virtuálním stroji na Apple Silicon (přes **UTM**, **Parallels** či **VMware Fusion**):

1. Otevřete terminál ve složce `mutable-dev-environment`:
   ```bash
   chmod +x setup-manjaro.sh
   ./setup-manjaro.sh
   ```

Skript provede:
- Detekci ARM vs x86_64.
- Instalaci nativních nástrojů (`arm-none-eabi-gcc`, `openocd`, `stlink`, `avr-gcc`).
- Nastavení symlinků pro Mutable makefily (`/usr/local/arm-4.8.3/` a `/usr/local/CrossPack-AVR`).
- Nastavení udev pravidel pro programátory (ST-Link V2, V3, Olimex, AVR ISP).
- Aktivaci profilu v `/etc/profile.d/mutable-dev.sh`.

---

## Varianta B: Docker / Kontejnery (Univerzální pro ARM i x86)

Pokud nechcete instalovat kompilátory přímo do systému:

```bash
chmod +x docker-build.sh

# Kompilace libovolného modulu:
./docker-build.sh clouds
./docker-build.sh plaits
./docker-build.sh elements

# Kompilace hex / wav souboru:
./docker-build.sh clouds hex
./docker-build.sh clouds wav

# Otevření interaktivního shellu:
./docker-build.sh bash
```

Na Windows s ARM procesorem (např. Snapdragon X Elite / Copilot+ PC):
```cmd
docker-build.bat clouds
```

---

## Varianta C: Vagrant / VirtualBox

Pro klasické x86_64 počítače s VirtualBoxem:
```bash
vagrant up
vagrant ssh
```
*(Poznámka: VirtualBox pro ARM na Apple Silicon zatím nemá plnou podporu pro virtualizaci x86 hostů. Pokud jste na Macu s Apple Silicon, doporučujeme použít Variantu A s UTM/Parallels nebo Variantu B s Dockerem).*

---

## Jak kompilovat a nahrávat firmware

Vždy kompilujte z kořenové složky `eurorack`:

### 1. Kompilace firmwaru:
```bash
make -f clouds/makefile
make -f elements/makefile
make -f plaits/makefile
```

### 2. Generování bootloader WAV souboru (pro nahrání přes audio kabel):
```bash
make -f clouds/makefile wav
```
Výsledný soubor naleznete v `build/clouds/clouds.wav`.

### 3. Nahrání přes ST-Link / Olimex:
```bash
# Pro ST-Link V2 / V3:
PGM_INTERFACE=stlink-v2 make -f clouds/makefile upload

# Pro Olimex:
PGM_INTERFACE=ftdi/olimex-arm-usb-tiny-h make -f clouds/makefile upload
```
