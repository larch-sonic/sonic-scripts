#!/bin/bash

# Copyright (c) Marvell, Inc. All rights reserved. Confidential.
# Description: Copy Larch platform files from HardenedSonic to a target
#              sonic-buildimage, commit, create a format-patch, and register
#              it in the appropriate series file.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { echo "[INFO]  $*"; }
warn() { echo "[WARN]  $*"; }
die()  { echo "[ERROR] $*" >&2; exit 1; }

# write_sai_mk <platform> <version> <branch> <dest_dir>
# Overwrites <dest_dir>/platform/<platform>/sai.mk with the prebuilt-download
# variant so the community sonic build fetches a pre-built .deb instead of
# building SAI from source.
write_sai_mk() {
    local platform="$1"
    local version="$2"
    local branch="$3"
    local dest="$4"
    local sai_mk="$dest/platform/$platform/sai.mk"

    [[ -f "$sai_mk" ]] || die "sai.mk not found after copy: $sai_mk"

    log "Writing prebuilt sai.mk  (platform=$platform  version=$version  branch=$branch)"

    case "$platform" in
        marvell-prestera)
            cat > "$sai_mk" <<SAIMK
# Marvell SAI
# Downloads pre-built package from sonic-larch-binaries

BRANCH = $branch
MRVL_SAI_VERSION = $version

MRVL_SAI_URL_PREFIX = https://github.com/larch-sonic/sonic-larch-binaries/raw/main/\$(CONFIGURED_ARCH)/sai-plugin/\$(BRANCH)/
MRVL_SAI = mrvllibsai_\$(MRVL_SAI_VERSION)_\$(PLATFORM_ARCH).deb
\$(MRVL_SAI)_URL = \$(MRVL_SAI_URL_PREFIX)/\$(MRVL_SAI)

SONIC_ONLINE_DEBS += \$(MRVL_SAI)
\$(MRVL_SAI)_SKIP_VERSION = y
\$(eval \$(call add_conflict_package,\$(MRVL_SAI),\$(LIBSAIVS_DEV)))
SAIMK
            ;;
        marvell-teralynx)
            cat > "$sai_mk" <<SAIMK
# MRVL_TERALYNX SAI
# Downloads pre-built package from sonic-larch-binaries

BRANCH = $branch
export MRVL_TERALYNX_LIBSAI_VER = $version

MRVL_TERALYNX_LIBSAI_URL_PREFIX = https://github.com/larch-sonic/sonic-larch-binaries/raw/main/\$(CONFIGURED_ARCH)/sai-plugin/\$(BRANCH)/teralynx/
MRVL_TERALYNX_LIBSAI = mrvllibsai_\$(MRVL_TERALYNX_LIBSAI_VER)_\$(PLATFORM_ARCH).deb
\$(MRVL_TERALYNX_LIBSAI)_URL = \$(MRVL_TERALYNX_LIBSAI_URL_PREFIX)/\$(MRVL_TERALYNX_LIBSAI)

SONIC_ONLINE_DEBS += \$(MRVL_TERALYNX_LIBSAI)
\$(MRVL_TERALYNX_LIBSAI)_SKIP_VERSION = y
\$(eval \$(call add_conflict_package,\$(MRVL_TERALYNX_LIBSAI),\$(LIBSAIVS_DEV)))
\$(SYNCD)_UNINSTALLS += \$(MRVL_TERALYNX_LIBSAI)
SAIMK
            ;;
        *)
            warn "No sai.mk template for platform '$platform' — sai.mk left as-is."
            return 0
            ;;
    esac
    log "sai.mk written: $sai_mk"
}

print_usage() {
    cat <<EOF
Usage:
  $0 --device <device_name> --platform <platform_name> --arch <arch>
     --dest <destination_sonic-buildimage_path>
     [--src  <source_sonic-buildimage_path>]
     [--commit-msg <message>]
     [--series-dir <path_to_series_dir>]

Required arguments:
  --device,  -d   Device subdirectory under device/larch/
                  (e.g. arm64-larch_canisminor, x86_64-larch_gemini)
  --platform,-p   Platform subdirectory under platform/
                  (e.g. marvell-teralynx, marvell-prestera)
  --arch,    -a   Architecture token used in the series filename
                  (e.g. amd64, arm64)
  --dest          Absolute or relative path to the destination
                  sonic-buildimage directory (must already be a git repo)

Optional arguments:
  --src           Source sonic-buildimage directory
                  [default: <workspace>/HardenedSonic/sonic-buildimage]
  --commit-msg,-m Git commit message
                  [default: "Add Larch <device_name> platform files"]
  --series-dir    Directory that holds the series files and patches
                  [default: <script_dir>/files/202511]
  --sai-version,-s  SAI .deb version to embed in platform/<platform>/sai.mk
                  (e.g. 1.17.4-2 for prestera, 6.2.1 for teralynx). Required.
  --help,    -h   Show this help and exit

Examples:
  $0 -d arm64-larch_canisminor -p marvell-teralynx -a amd64 \\
     --dest ~/ComSonic/sonic-scripts/ABP-202511-.../sonic-buildimage

  $0 -d x86_64-larch_gemini -p marvell-amd64 -a amd64 \\
     --dest /path/to/dest/sonic-buildimage \\
     --src  /path/to/src/sonic-buildimage \\
     -m "Add larch gemini platform support"
EOF
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
DEVICE_NAME=""
PLATFORM_NAME=""
ARCH=""
DEST_DIR=""
SRC_DIR=""
COMMIT_MSG=""
SERIES_DIR=""
SAI_VERSION=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --device|-d)
            DEVICE_NAME="$2"; shift 2 ;;
        --platform|-p)
            PLATFORM_NAME="$2"; shift 2 ;;
        --arch|-a)
            ARCH="$2"; shift 2 ;;
        --dest)
            DEST_DIR="$2"; shift 2 ;;
        --src)
            SRC_DIR="$2"; shift 2 ;;
        --commit-msg|-m)
            COMMIT_MSG="$2"; shift 2 ;;
        --series-dir)
            SERIES_DIR="$2"; shift 2 ;;
        --sai-version|-s)
            SAI_VERSION="$2"; shift 2 ;;
        --help|-h)
            print_usage; exit 0 ;;
        *)
            die "Unknown argument: $1\nRun '$0 --help' for usage." ;;
    esac
done

# ---------------------------------------------------------------------------
# Validate required arguments
# ---------------------------------------------------------------------------
[[ -n "$DEVICE_NAME"   ]] || die "--device is required."
[[ -n "$PLATFORM_NAME" ]] || die "--platform is required."
[[ -n "$ARCH"          ]] || die "--arch is required."
[[ -n "$DEST_DIR"      ]] || die "--dest is required."
[[ -n "$SAI_VERSION"   ]] || die "--sai-version is required."

# ---------------------------------------------------------------------------
# Apply defaults and resolve to absolute paths
# ---------------------------------------------------------------------------
if [[ -z "$SRC_DIR" ]]; then
    # Default: two levels up from sonic-scripts -> workspace root -> HardenedSonic
    SRC_DIR="$SCRIPT_DIR/../../HardenedSonic/sonic-buildimage"
fi

if [[ -z "$COMMIT_MSG" ]]; then
    if [[ -n "$SAI_VERSION" ]]; then
        COMMIT_MSG="Add Larch ${DEVICE_NAME} platform files and update sai.mk to prebuilt v${SAI_VERSION}"
    else
        COMMIT_MSG="Add Larch ${DEVICE_NAME} platform files"
    fi
fi

if [[ -z "$SERIES_DIR" ]]; then
    SERIES_DIR="$SCRIPT_DIR/files/202511"
fi

SRC_DIR=$(realpath "$SRC_DIR")
DEST_DIR=$(realpath "$DEST_DIR")
SERIES_DIR=$(realpath "$SERIES_DIR")

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
log "=== Pre-flight checks ==="

[[ -d "$SRC_DIR"  ]] || die "Source directory not found: $SRC_DIR"
[[ -d "$DEST_DIR" ]] || die "Destination directory not found: $DEST_DIR"
[[ -d "$DEST_DIR/.git" ]] || die "Destination is not a git repository: $DEST_DIR"

SRC_DEVICE_DIR="$SRC_DIR/device/larch/$DEVICE_NAME"
SRC_PLATFORM_DIR="$SRC_DIR/platform/$PLATFORM_NAME"

[[ -d "$SRC_DEVICE_DIR"   ]] || die "Source device directory not found:   $SRC_DEVICE_DIR"
[[ -d "$SRC_PLATFORM_DIR" ]] || die "Source platform directory not found: $SRC_PLATFORM_DIR"

log "Source:      $SRC_DIR"
log "Destination: $DEST_DIR"
log "Device:      $DEVICE_NAME"
log "Platform:    $PLATFORM_NAME"
log "Arch:        $ARCH"
log "Series dir:  $SERIES_DIR"
echo ""

# ---------------------------------------------------------------------------
# Step 1: Copy directories
# ---------------------------------------------------------------------------
log "=== Step 1: Copying platform directories ==="

DEST_DEVICE_DIR="$DEST_DIR/device/larch/$DEVICE_NAME"
DEST_PLATFORM_DIR="$DEST_DIR/platform/$PLATFORM_NAME"

log "Copying device:   $SRC_DEVICE_DIR  ->  $DEST_DEVICE_DIR"
mkdir -p "$(dirname "$DEST_DEVICE_DIR")"
cp -r "$SRC_DEVICE_DIR" "$DEST_DEVICE_DIR"

log "Copying platform: $SRC_PLATFORM_DIR  ->  $DEST_PLATFORM_DIR"
mkdir -p "$(dirname "$DEST_PLATFORM_DIR")"
cp -r "$SRC_PLATFORM_DIR" "$DEST_PLATFORM_DIR"

log "Directories copied successfully."
echo ""

# ---------------------------------------------------------------------------
# Step 1b: Overwrite sai.mk with prebuilt-download version
# ---------------------------------------------------------------------------
log "=== Step 1b: Writing prebuilt sai.mk ==="
SAI_BRANCH=$(basename "$SERIES_DIR")
write_sai_mk "$PLATFORM_NAME" "$SAI_VERSION" "$SAI_BRANCH" "$DEST_DIR"
echo ""

# ---------------------------------------------------------------------------
# Step 2: Stage and commit
# ---------------------------------------------------------------------------
log "=== Step 2: Staging and committing ==="
cd "$DEST_DIR"

git add "device/larch/$DEVICE_NAME" "platform/$PLATFORM_NAME"

if git diff --cached --quiet; then
    die "Nothing to commit — files may already be identical to the repository state."
fi

git commit -m "$COMMIT_MSG"
log "Committed: $COMMIT_MSG"
echo ""

# ---------------------------------------------------------------------------
# Step 3: Generate format-patch
# ---------------------------------------------------------------------------
log "=== Step 3: Generating format-patch ==="

# format-patch outputs the patch filename; capture it.
PATCH_FILE=$(git format-patch -1 HEAD)
PATCH_BASENAME=$(basename "$PATCH_FILE")
# PATCH_FILE is relative to $DEST_DIR at this point
PATCH_ABS="$DEST_DIR/$PATCH_FILE"

log "Patch created: $PATCH_ABS"
echo ""

# ---------------------------------------------------------------------------
# Step 4: Copy patch to series directory
# ---------------------------------------------------------------------------
log "=== Step 4: Copying patch to series directory ==="
mkdir -p "$SERIES_DIR"
cp "$PATCH_ABS" "$SERIES_DIR/"
log "Patch copied to: $SERIES_DIR/$PATCH_BASENAME"
echo ""

# ---------------------------------------------------------------------------
# Step 5: Update (or create) series file
# ---------------------------------------------------------------------------
log "=== Step 5: Updating series file ==="

SERIES_FILE="$SERIES_DIR/series_${PLATFORM_NAME}_${ARCH}"
SERIES_ENTRY="${PATCH_BASENAME}|sonic-buildimage"

if [[ -f "$SERIES_FILE" ]]; then
    if grep -qF "$SERIES_ENTRY" "$SERIES_FILE"; then
        warn "Series file already contains entry: $SERIES_ENTRY  (no change)"
    else
        # Remove any trailing blank lines, append entry, ensure trailing newline
        sed -i -e '/^[[:space:]]*$/d' "$SERIES_FILE"
        printf '%s\n' "$SERIES_ENTRY" >> "$SERIES_FILE"
        log "Appended to series file: $SERIES_ENTRY"
    fi
else
    log "Creating new series file: $SERIES_FILE"
    printf '%s\n' "$SERIES_ENTRY" > "$SERIES_FILE"
fi

echo ""
log "=== Done ==="
log "Patch file:   $SERIES_DIR/$PATCH_BASENAME"
log "Series file:  $SERIES_FILE"
