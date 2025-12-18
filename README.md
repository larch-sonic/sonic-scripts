# sonic-scripts

# 1. Build using script
./sonic_build_script.sh
Branch is not set. Please check usage.
Usage:

 ./sonic_build_script.sh -b <branch> -p <platform> -a <arch>
   [-c <sonic-buildimage_commit>]
   [--patch_script <http or full_local path_of_patch_script>]
   [--url <sonic-buildimage_url>]
   [--SAI <url full path to mrvllibsai_*.deb>]
   [-s] [-r] [--mark_no_del_ws] [--no-cache]
   [--admin_password <password>] [--other_build_options <sonic_build_options>]
   [--verify_patches] [--clean_dockers] [--clean_ws]

    -s : Build docker saiserver v2
    -r : ENABLE_SYNCD_RPC=y
    -c : checkout commit id
    -C : clone, patching, make-CONFIGURE and exit before full make
                             (for inspection and re-config)
    --no-cache: Build without any pre cache
    --mark_no_del_ws: Do not cleanup ws during cleanup
    --admin_password: Set admin password
    --other_build_options: Other sonic build options
    --verify_patches:    Apply patches, don't compile. Abort on failure
        export DEVEL=y   Ignore patch apply failures but continue
    --clean_dockers: clean up build dockers

Example command:
"./sonic_build_script.sh -b 202411 -p marvell -a arm64   --patch_script https://github.com/larch-sonic/sonic-scripts/raw/refs/heads/main/larch_sonic_patch_script.sh -r -c b6a493b43d73831a7a40180ef428ef50185bc8ed" ,

where: -b 202411 - original branch in the sonic-buildimage repository,
       -p marvell - switch ASIC type(marvell - as Marvell Prestera family), marvell-larch-sim - simulation qemu image
       -a arm64 - device/board CPU architecture (arm64 or amd64)
       --patch_script https://github.com/larch-sonic/sonic-scripts/raw/refs/heads/main/larch_sonic_patch_script.sh - patch script that make changes to original repos,
       -r - ENABLE_SYNCD_RPC=y,
       -c b6a493b43d73831a7a40180ef428ef50185bc8ed - checkout to static stable commit.


# Build manually
1. Clone sonic-buildimage repository
git clone git@github.com:larch-sonic/sonic-buildimage.git -b 202411
2. Go to the directory 
cd sonic-buildimage
3. Checkout to the stable commit
git checkout b6a493b43d73831a7a40180ef428ef50185bc8ed
4. Get patch script
wget --timeout=2 -c https://github.com/larch-sonic/sonic-scripts/raw/refs/heads/main/larch_sonic_patch_script.sh
5. Make the script executable
chmod +x larch_sonic_patch_script.sh



6. Building
for arm64:
    - Execute patch script
    bash larch_sonic_patch_script.sh --branch 202411 --platform marvell --arch arm64 --url https://github.com/larch-sonic/sonic-scripts/raw/refs/heads/main/
    -  Configure the build system for target
    make configure NOBUSTER=1 NOBULLSEYE=1 PLATFORM=marvell PLATFORM_ARCH=arm64
    - Start building
    make SONIC_BUILD_JOBS=8 NOBUSTER=1 NOBULLSEYE=1 SONIC_DPKG_CACHE_METHOD=rwcache target/sonic-marvell-arm64.bin

for amd64:
    - Execute patch script
    bash larch_sonic_patch_script.sh --branch 202411 --platform marvell --arch amd64 --url https://github.com/larch-sonic/sonic-scripts/raw/refs/heads/main/
    -  Configure the build system for target
    make configure NOBUSTER=1 NOBULLSEYE=1 PLATFORM=marvell PLATFORM_ARCH=amd64
    - Start building
    make SONIC_BUILD_JOBS=8 NOBUSTER=1 NOBULLSEYE=1 SONIC_DPKG_CACHE_METHOD=rwcache target/sonic-marvell.bin

for amd64 simulation:
    - Execute patch script
    bash larch_sonic_patch_script.sh --branch 202411 --platform marvell-larch-sim --arch amd64 --url https://github.com/larch-sonic/sonic-scripts/raw/refs/heads/main/
    -  Configure the build system for target
    make configure NOBUSTER=1 NOBULLSEYE=1 PLATFORM=marvell-larch-sim PLATFORM_ARCH=amd64
    - Start building
    make SONIC_BUILD_JOBS=8 NOBUSTER=1 NOBULLSEYE=1 SONIC_DPKG_CACHE_METHOD=rwcache target/sonic-vs.img.gz






