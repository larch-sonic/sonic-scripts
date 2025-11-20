#!/bin/bash

# Copyright (c) Marvell, Inc. All rights reservered. Confidential.
# Description: Applying open PRs needed for compilation


#
# patch script for ARM64 Falcon and AC5X board
#

#
# CONFIGURATIONS:-
#

SONIC_COMMIT="b6a493b43d73831a7a40180ef428ef50185bc8ed"
SAI_COMMIT="v1.16.1"

#
# END of CONFIGURATIONS
#

# PREDEFINED VALUES
CUR_DIR=$(basename `pwd`)
LOG_FILE=patches_result.log
FULL_PATH=`pwd`

# Path for master patches
WGET_PATH="https://raw.githubusercontent.com/larch-sonic/sonic-scripts/main/files/202411/patches/"

# Patches
SERIES="0001-Add-Larch-Networks-platforms-and-Larch-SAI.patch
        "

PATCHES=""

# Sub module patches
declare -a SUB_PATCHES=(SP1 SP2)
declare -A SP1=([NAME]="0001-Patch-for-SAI-to-support-Larch-changes.patch" [DIR]="src/sonic-sairedis/SAI")
declare -A SP2=([NAME]="0001-Move-sai-redis-to-SAI-v1.16.1-with-Larch-Networks-pa.patch" [DIR]="src/sonic-sairedis")


log()
{
    echo $@
    echo $@ >> ${FULL_PATH}/${LOG_FILE}
}

pre_patch_help()
{
    log "STEPS TO BUILD:"
    log "git clone https://github.com/sonic-net/sonic-buildimage.git"
    log "cd sonic-buildimage"
    log "git checkout $SONIC_COMMIT"
    log "make init"

    log "<<Apply patches using patch script>>"
    log "bash $0"

    log "<<FOR ARM64>> make configure PLATFORM=marvell-arm64 PLATFORM_ARCH=arm64"
    log "<<FOR INTEL>> make configure PLATFORM=marvell"
    log "make all"
}

apply_patch_series()
{
    for patch in $SERIES
    do
        echo $patch
        pushd patches
        wget -c $WGET_PATH/$patch
        popd
        git am patches/$patch
        if [ $? -ne 0 ]; then
            log "ERROR: Failed to apply patch $patch"
            exit 1
        fi
    done
}

apply_patches()
{
    for patch in $PATCHES
    do
	echo $patch	
    	pushd patches
    	wget -c $WGET_PATH/$patch
        popd
	    patch -p1 < patches/$patch
        if [ $? -ne 0 ]; then
	        log "ERROR: Failed to apply patch $patch"
            exit 1
    	fi
    done
}

apply_submodule_patches()
{
    CWD=`pwd`
    for SP in ${SUB_PATCHES[*]}
    do
	patch=${SP}[NAME]
	dir=${SP}[DIR]
	echo "${!patch}"
    	pushd patches
    	wget -c $WGET_PATH/${!patch}
        popd
	    pushd ${!dir}
        git am $CWD/patches/${!patch}
        if [ $? -ne 0 ]; then
	        log "ERROR: Failed to apply patch ${!patch}"
            exit 1
    	fi
	popd
    done
}

apply_hwsku_changes()
{
    # Add hwsku changes if any
    # For now this changes are in the patch files
}

update_sai_version()
{
    # Update SAI version if needed
    pushd src/sonic-sairedis/SAI

    SAI_commit=`git rev-parse HEAD`
    if [ "$CUR_DIR" != "SAI" ]; then
        log "ERROR: Need to be at SAI git clone path"
        pre_patch_help
        exit
    fi

    if [ "${SAI_commit}" != "$SAI_COMMIT" ]; then
        log "Checkout SAI commit to proceed"
        log "git checkout ${SAI_COMMIT}"
        git checkout ${SAI_COMMIT}
    fi
    popd
}

main()
{
    sonic_buildimage_commit=`git rev-parse HEAD`
    if [ "$CUR_DIR" != "sonic-buildimage" ]; then
        log "ERROR: Need to be at sonic-builimage git clone path"
        pre_patch_help
        exit
    fi

    if [ "${sonic_buildimage_commit}" != "$SONIC_COMMIT" ]; then
        log "Checkout sonic-buildimage commit to proceed"
        log "git checkout ${SONIC_COMMIT}"
        pre_patch_help
        exit
    fi

    date > ${FULL_PATH}/${LOG_FILE}
    [ -d patches ] || mkdir patches

    # Apply patch series
    apply_patch_series
    # Apply patches
    apply_patches
    # Update SAI version
    update_sai_version
    # Apply submodule patches
    apply_submodule_patches
    # Apply hwsku changes
    apply_hwsku_changes
}

main $@