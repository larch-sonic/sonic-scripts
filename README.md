# sonic-scripts

Build scripts for SONiC images targeting Larch Networks / Marvell Prestera platforms.

---

## 1. Build Using Script

### Usage

```
./sonic_build_script.sh -b <branch> -p <platform> -a <arch>
   [-c <sonic-buildimage_commit>]
   [--patch_script <http or full_local path_of_patch_script>]
   [--url <sonic-buildimage_url>]
   [--SAI <url full path to mrvllibsai_*.deb>]
   [-s] [-r] [--mark_no_del_ws] [--no-cache]
   [--admin_password <password>] [--other_build_options <sonic_build_options>]
   [--verify_patches] [--clean_dockers] [--clean_ws]
```

### Options

| Flag | Description |
|------|-------------|
| `-b <branch>` | Original branch in the sonic-buildimage repository |
| `-p <platform>` | Switch ASIC type (`marvell-prestera`, `marvell-larch-sim`) |
| `-a <arch>` | Device/board CPU architecture (`arm64` or `amd64`) |
| `-c <commit>` | Checkout specific commit ID |
| `-C` | Clone, patch, run `make configure`, then exit before full make (for inspection) |
| `-s` | Build docker saiserver v2 |
| `-r` | Enable `ENABLE_SYNCD_RPC=y` |
| `--patch_script <path>` | HTTP URL or local path to the patch script |
| `--url <url>` | Custom sonic-buildimage git URL |
| `--SAI <url>` | Full URL path to `mrvllibsai_*.deb` |
| `--no-cache` | Build without any pre-cache |
| `--mark_no_del_ws` | Do not cleanup workspace during cleanup |
| `--admin_password <pw>` | Set admin password |
| `--other_build_options <opts>` | Additional sonic build options |
| `--verify_patches` | Apply patches only (don't compile); abort on failure |
| `--clean_dockers` | Clean up build dockers |
| `--clean_ws` | Clean up old workspaces |

> **Tip:** Set `export DEVEL=y` to ignore patch apply failures and continue.

### Examples

**ARM64 hardware build (Marvell Prestera):**

```bash
./sonic_build_script.sh -b 202511 -p marvell-prestera -a arm64 \
  -c d7aa7e9c120ff00d9838f9f3b706bee3b1bbe2bb \
  --patch_script https://github.com/larch-sonic/sonic-scripts/raw/refs/heads/main/larch_sonic_patch_script.sh \
  --other_build_options "SONIC_BUILD_JOBS=8"
```

**AMD64 simulation build (Larch SIM):**

```bash
./sonic_build_script.sh -b 202511 -p marvell-larch-sim -a amd64 \
  --patch_script https://github.com/larch-sonic/sonic-scripts/raw/refs/heads/main/larch_sonic_patch_script.sh \
  --other_build_options "SONIC_BUILD_JOBS=8"
```

---

## 2. Build Manually

### Prerequisites

1. Clone the sonic-buildimage repository:

   ```bash
   git clone git@github.com:larch-sonic/sonic-buildimage.git -b 202511
   cd sonic-buildimage
   ```

2. Checkout the stable commit:

   ```bash
   git checkout d7aa7e9c120ff00d9838f9f3b706bee3b1bbe2bb
   ```

3. Get the patch script:

   ```bash
   wget --timeout=2 -c https://github.com/larch-sonic/sonic-scripts/raw/refs/heads/main/larch_sonic_patch_script.sh
   chmod +x larch_sonic_patch_script.sh
   ```

### Build Targets

#### ARM64

```bash
bash larch_sonic_patch_script.sh --branch 202511 --platform marvell --arch arm64 \
  --url https://github.com/larch-sonic/sonic-scripts/raw/refs/heads/main/

make configure NOBUSTER=1 NOBULLSEYE=1 PLATFORM=marvell-prestera PLATFORM_ARCH=arm64

make SONIC_BUILD_JOBS=8 NOBUSTER=1 NOBULLSEYE=1 SONIC_DPKG_CACHE_METHOD=rwcache \
  target/sonic-marvell-arm64.bin
```

#### AMD64

```bash
bash larch_sonic_patch_script.sh --branch 202511 --platform marvell --arch amd64 \
  --url https://github.com/larch-sonic/sonic-scripts/raw/refs/heads/main/

make configure NOBUSTER=1 NOBULLSEYE=1 PLATFORM=marvell-prestera PLATFORM_ARCH=amd64

make SONIC_BUILD_JOBS=8 NOBUSTER=1 NOBULLSEYE=1 SONIC_DPKG_CACHE_METHOD=rwcache \
  target/sonic-marvell.bin
```

#### AMD64 Simulation (QEMU)

```bash
bash larch_sonic_patch_script.sh --branch 202511 --platform marvell-larch-sim --arch amd64 \
  --url https://github.com/larch-sonic/sonic-scripts/raw/refs/heads/main/

make configure NOBUSTER=1 NOBULLSEYE=1 PLATFORM=marvell-larch-sim PLATFORM_ARCH=amd64

make SONIC_BUILD_JOBS=8 NOBUSTER=1 NOBULLSEYE=1 SONIC_DPKG_CACHE_METHOD=rwcache \
  target/sonic-vs.img.gz
```






