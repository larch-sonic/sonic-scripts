#!/bin/bash

# Copyright (c) Marvell, Inc. All rights reservered. Confidential.
# Description: Applying open PRs needed for compilation
#
# Sonic patch script for Marvell board
#

#
# CONFIGURATIONS:-
#

#
# END of CONFIGURATIONS
#


# PREDEFINED VALUES
CUR_DIR=$(basename `pwd`)
LOG_FILE=patches_result.log
FULL_PATH=`pwd`
err_cnt=0
SAI_COMMIT="v1.17.4"

# VERIFY_PATCHES=Y may be selected by MRVL sonic_build_script.sh
if [[ "$DEVEL" == "" || "$VERIFY_PATCHES" == "Y" ]]; then
  PATCH_ERR_SKIP=
else
  PATCH_ERR_SKIP=Y
fi

log()
{
	echo $@
	echo $@ >> ${FULL_PATH}/${LOG_FILE}
}

print_usage()
{
	log "Usage:"
	log ""
	log " bash $0 --branch <> --platform <marvell|marvell-prestera|innovium|marvell-teralynx> --arch <amd64|arm64> --release-tag <>"
	log ""
	log ""
}

pre_patch_help()
{
	log "STEPS TO BUILD:"
	log "git clone https://github.com/sonic-net/sonic-buildimage.git -b <sonic_branch>"
	log "cd sonic-buildimage"
	log "<<Apply patches using patch script for sonic-buildimage>>"
	log "make init"
	log "git submodule update --init --recursive (instead of make init)"
	log ""
	log "<<Apply patches using patch script for submodules>>"
	print_usage
	log "PLATFORM: marvell"
	log "<<FOR ARM64>> make configure PLATFORM=marvell PLATFORM_ARCH=arm64"
	log "<<FOR ARM64>> make target/sonic-marvell-arm64.bin"
	log "<<FOR INTEL>> make configure PLATFORM=marvell"
	log "<<FOR INTEL>> make target/sonic-marvell.bin"
	log ""
	log "PLATFORM: innovium"
	log "<<FOR INTEL>> make configure PLATFORM=innovium"
	log "<<FOR INTEL>> make target/sonic-innovium.bin"
	log ""
	log "PLATFORM: marvell-teralynx"
	log "<<FOR INTEL>> make configure PLATFORM=marvell-teralynx"
	log "<<FOR INTEL>> make target/sonic-marvell-teralynx.bin"
	log ""
}

parse_arguments()
{
	while [[ $# -gt 0 ]]; do
		case $1 in
			-b|--branch)
				BRANCH="$2"
				shift # past argument
				shift # past value
				;;
			-p|--platform)
				PLATFORM="$2"
				shift # past argument
				shift # past value
				;;
			-a|--arch)
				ARCH="$2"
				shift # past argument
				shift # past value
				;;
			-t|--release-tag)
				GIT_TAG="$2"
				shift # past argument
				shift # past value
				;;
			--url)
				URL="$2"
				shift # past argument
				shift # past value
				;;
			-h|--help)
				print_usage
				exit 0
				;;
			*)
				echo "ERROR: Unknown option '$1'"
				print_usage
				exit 1
				;;
		esac
	done

	if [ -z "${BRANCH}" ]; then
		echo "Branch is not set. Please check usage."
		print_usage
		exit 0
	fi

	if [ -z "${ARCH}" ]; then
		echo "Arch is not set. Please check usage."
		print_usage
		exit 0
	fi

	if [[ -z "${GIT_TAG}" && -z "${URL}" ]]; then
		echo "Github release tag is not set. Please check usage."
		print_usage
		exit 0
	fi

	if [ -z "${PLATFORM}" ]; then
		echo "Platform is not set. Please check usage."
		print_usage
		exit 0
	fi

	if [ -z "${URL}" ]; then
		WGET_PATH="https://raw.githubusercontent.com/larch-sonic/sonic-scripts/$GIT_TAG/files/$BRANCH/"
	else
		WGET_PATH=$URL/files/$BRANCH
	fi
}

wget_cp()
{
    if [[ "$1" == *:* ]]; then
        # Is URL - use wget
        wget --timeout=2 -c $1
    else
        # Dir or File is on local path
        cp -r $1 .
    fi
}

apply_sonicbuildimage_patches()
{
 cat series_${PLATFORM}_${ARCH} | grep -v -E '^#|^$' | grep sonic-buildimage | cut -f 1 -d'|' | while read -r patch_file
 do
	echo $patch_file
	pushd patches
	wget_cp $WGET_PATH/$patch_file
	popd
	git am --3way patches/$patch_file
	ret=$?
	if [ $ret -ne 0 ]; then
        ((err_cnt++))
		if [ "$PATCH_ERR_SKIP" == "" ]; then
			log "PATCH ERROR: Failed to apply sonicbuildimage patches/$patch_file, abort"
			return $ret
		fi
		log "PATCH ERROR: Failed to apply sonicbuildimage patches/$patch_file, skeep and continue"
		git am --skip
	fi
 done
}

apply_submodule_patches()
{
	CWD=`pwd`
 cat series_${PLATFORM}_${ARCH} | grep -v -E '^#|^$' | grep -v sonic-buildimage | while read -r line
 do
	patch=`echo $line | cut -f 1 -d'|'`
	dir=`echo $line | cut -f 2 -d'|'`
	pushd patches
	wget_cp $WGET_PATH/${patch}
	popd
	pushd ${dir}
	git am --3way $CWD/patches/${patch}
	ret=$?
	if [ $ret -ne 0 ]; then
        ((err_cnt++))
		if [ "$PATCH_ERR_SKIP" == "" ]; then
			log "PATCH ERROR: Failed to apply submodule $CWD/patches/${patch}, abort"
			return $ret
		fi
		log "PATCH ERROR: Failed to apply submodule $CWD/patches/${patch}, skeep and continue"
		git am --skip
	fi
	popd
 done
}

apply_hwsku_changes()
{
	if [ "$PLATFORM" == "marvell" ] || [ "$PLATFORM" == "marvell-prestera" ]; then
		# Download hwsku
		wget_cp $WGET_PATH/prestera_hwsku.tgz
		if [ $? -eq 0 ]; then
			rm -fr device/marvell/x86_64-marvell_db* || true
			tar -C device/ -xzf prestera_hwsku.tgz
		fi
	fi
	if [ "$PLATFORM" == "innovium" ] || [ "$PLATFORM" == "marvell-teralynx" ]; then
		# Download hwsku
		wget_cp $WGET_PATH/teralynx_hwsku.tgz
		if [ $? -eq 0 ]; then
			rm -fr device/celestica/x86_64-cel_midstone-r0 || true
			rm -fr device/wistron || true
			tar -C device/ -xzf teralynx_hwsku.tgz
		fi
	fi
}

update_sai_version()
{
    # Update SAI version if needed
    pushd src/sonic-sairedis/SAI
    CUR_DIR=$(basename `pwd`)
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
	CUR_DIR=$(basename `pwd`)
}

main()
{
	if [ "$CUR_DIR" != "sonic-buildimage" ]; then
		log "ERROR: Need to be at sonic-builimage git clone path"
		pre_patch_help
		exit 1
	fi
	parse_arguments $@

	date > ${FULL_PATH}/${LOG_FILE}
	[ -d patches ] || mkdir patches

	# wget patch series file
	wget_cp $WGET_PATH/series_${PLATFORM}_${ARCH}
	if [ ! -f series_${PLATFORM}_${ARCH} ]; then
		log "ERROR: Series file series_${PLATFORM}_${ARCH} not found"
		exit 1
	fi

	# Apply patch
	log "Apply sonicbuildimage patches"
	apply_sonicbuildimage_patches
	if [ $? -ne 0 ]; then
		# log ERROR already printed
		exit 1
	fi

	# Remove host-base-image version directory: pinned versions include
	# binNMU (+bN) rebuilds not available in Debian snapshot mirrors.
	# Without this dir, build_debian_base_system.sh uses plain debootstrap.
	if [ -d files/build/versions/host-base-image ]; then
		log "Removing host-base-image version pins (binNMU pins not in snapshot)"
		git rm -rf files/build/versions/host-base-image
		git commit -m "Remove host-base-image version pins to use plain debootstrap"
	fi

	# Overwrite sai.mk to use Larch prebuilt SAI .deb (prestera only)
	if [ -d platform/marvell-prestera ]; then
		log "Overwrite platform/marvell-prestera/sai.mk (prebuilt SAI v1.17.4-1)"
		cat > platform/marvell-prestera/sai.mk << 'EOF'
# Marvell SAI

BRANCH = 202511
MRVL_SAI_VERSION = 1.17.4-1

MRVL_SAI_URL_PREFIX = https://github.com/larch-sonic/sonic-larch-binaries/raw/main/$(CONFIGURED_ARCH)/sai-plugin/$(BRANCH)/
MRVL_SAI = mrvllibsai_$(MRVL_SAI_VERSION)_$(PLATFORM_ARCH).deb
$(MRVL_SAI)_URL = $(MRVL_SAI_URL_PREFIX)/$(MRVL_SAI)

SONIC_ONLINE_DEBS += $(MRVL_SAI)
$(MRVL_SAI)_SKIP_VERSION=y
$(eval $(call add_conflict_package,$(MRVL_SAI),$(LIBSAIVS_DEV)))
EOF
		git add platform/marvell-prestera/sai.mk
		git commit -m "Switch sai.mk to Larch prebuilt SAI v1.17.4-1"
	fi

	# Ensure libi2c-dev is available for platform package build.
	# The sonic slave docker pulled from registry may not have it.
	# Remove libi2c-dev from Build-Depends (so dpkg-buildpackage doesn't
	# fail on dep check) and install it in override_dh_auto_build instead.
	# Use apt-get download + dpkg -i because apt install is broken (libnl conflict).
	if [ -f platform/marvell-prestera/sonic-platform-larch/debian/rules ]; then
		RULES_FILE=platform/marvell-prestera/sonic-platform-larch/debian/rules
		CONTROL_FILE=platform/marvell-prestera/sonic-platform-larch/debian/control
		if ! grep -q 'apt-get download.*libi2c' "$RULES_FILE"; then
			log "Fix libi2c-dev: remove from Build-Depends, install in rules via dpkg"
			# Remove libi2c-dev from Build-Depends in debian/control
			if [ -f "$CONTROL_FILE" ]; then
				sed -i 's/Build-Depends:\(.*\), libi2c-dev/Build-Depends:\1/' "$CONTROL_FILE"
				sed -i 's/Build-Depends: libi2c-dev, /Build-Depends: /' "$CONTROL_FILE"
				sed -i 's/Build-Depends: libi2c-dev$/Build-Depends:/' "$CONTROL_FILE"
				git add "$CONTROL_FILE"
			fi
			# Install libi2c-dev via download+dpkg (bypasses broken apt state)
			sed -i '/^override_dh_auto_build:/a\\tsudo apt-get update -o Acquire::AllowInsecureRepositories=true -o Acquire::AllowDowngradeToInsecureRepositories=true 2>/dev/null || true\n\tapt-get download libi2c-dev libi2c0 2>/dev/null && sudo dpkg -i --force-depends ./libi2c*.deb 2>/dev/null && rm -f ./libi2c*.deb || true' "$RULES_FILE"
			git add "$RULES_FILE"
			git commit -m "Fix libi2c-dev: remove from Build-Depends, install in rules via dpkg"
		fi
	fi

	# Fix libnl version conflict in the BUILD SLAVE (trixie):
	# During package builds, sonic libnl (3.7.0-0.2+b1sonic1) gets installed
	# into the slave via the -install mechanism, replacing stock libnl-3-dev.
	# This breaks stock libnl-genl-3-dev and libnl-route-3-dev which depend
	# on libnl-3-dev (= 3.7.0-2).  Any subsequent apt operation on the slave
	# then fails with "Unmet dependencies".
	# Fix: Change the kbuild install from apt (which checks global dep state)
	# to dpkg -i --force-depends (which only installs the package).
	if [ -f build_debian.sh ]; then
		if ! grep -q 'dpkg -i --force-depends.*linux-kbuild' build_debian.sh; then
			log "Patch build_debian.sh to fix libnl conflict in slave"
			sed -i 's|sudo LANG=C DEBIAN_FRONTEND=noninteractive apt -y --allow-downgrades install \./\$debs_path/linux-kbuild-\${LINUX_KERNEL_VERSION}\*_\${CONFIGURED_ARCH}\.deb|sudo dpkg -i --force-depends ./$debs_path/linux-kbuild-${LINUX_KERNEL_VERSION}*_${CONFIGURED_ARCH}.deb|' build_debian.sh
			git add build_debian.sh
			git commit -m "Fix libnl version conflict in build slave"
		fi
	fi

	# Fix libnl version conflict in the TARGET ROOTFS:
	# Stock libnl -dev packages (3.7.0-2) get installed by apt as deps
	# during rootfs assembly. Then sonic's install_deb_package replaces
	# runtime libs with its own build (3.7.0-0.2+b1sonic1), breaking the
	# -dev deps.  Later apt-get commands detect broken state and exit
	# non-zero, killing the set -e script.
	# Fix: force-install all sonic libnl debs and hold them so
	# apt-get install -f cannot downgrade them back to stock.
	EXTENSION_J2=files/build_templates/sonic_debian_extension.j2
	if [ -f "$EXTENSION_J2" ]; then
		log "Patch sonic_debian_extension.j2 to fix libnl version conflict"
		sed -i '/^install_deb_package {{installer_debs.strip()}}/i \
# Fix libnl version conflict: force-install all sonic libnl debs and hold them\
# Must run BEFORE install_deb_package which triggers apt-get install -f\
LIBNL_SONIC_DEBS=$(ls $debs_path/libnl-3-200_*sonic*.deb $debs_path/libnl-3-dev_*sonic*.deb $debs_path/libnl-genl-3-200_*sonic*.deb $debs_path/libnl-genl-3-dev_*sonic*.deb $debs_path/libnl-route-3-200_*sonic*.deb $debs_path/libnl-route-3-dev_*sonic*.deb $debs_path/libnl-nf-3-200_*sonic*.deb $debs_path/libnl-nf-3-dev_*sonic*.deb $debs_path/libnl-cli-3-200_*sonic*.deb $debs_path/libnl-cli-3-dev_*sonic*.deb 2>/dev/null)\
if [ -n "$LIBNL_SONIC_DEBS" ]; then\
    sudo cp $LIBNL_SONIC_DEBS $FILESYSTEM_ROOT/\
    LIBNL_BASENAMES=$(basename -a $LIBNL_SONIC_DEBS)\
    sudo LANG=C DEBIAN_FRONTEND=noninteractive chroot $FILESYSTEM_ROOT dpkg --force-depends --force-overwrite -i $LIBNL_BASENAMES 2>/dev/null || true\
    ( cd $FILESYSTEM_ROOT; sudo rm -f $LIBNL_BASENAMES )\
    # Hold all libnl packages to prevent apt-get install -f from downgrading\
    for hlpkg in libnl-3-200 libnl-3-dev libnl-genl-3-200 libnl-genl-3-dev libnl-route-3-200 libnl-route-3-dev libnl-nf-3-200 libnl-nf-3-dev libnl-cli-3-200 libnl-cli-3-dev; do\
        sudo LANG=C chroot $FILESYSTEM_ROOT apt-mark hold $hlpkg 2>/dev/null || true\
    done\
fi\
' "$EXTENSION_J2"
		git add "$EXTENSION_J2"
		git commit -m "Fix libnl version conflict in rootfs assembly"
	fi

	echo "make init" >> build_cmd.txt
	make init
	git submodule sync --recursive
	git submodule update --init --recursive
	# Update SAI version
	log "Update SAI version"
	update_sai_version
	log "Apply submodule patches"
	# Apply submodule patches
	apply_submodule_patches
	if [ $? -ne 0 ]; then
		# log ERROR already printed
		exit 1
	fi
	log "Apply hwsku changes"
	# Apply hwsku changes
	# No need to apply hwsku changes as they are part of patch files
	#apply_hwsku_changes
	log "Patch script - DONE"
}

main $@