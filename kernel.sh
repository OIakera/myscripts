#!/usr/bin/env bash

# Kernel CI build script By akirasupr@xda

#-----------------------------------------------------------#

# Configure system
export TZ=Asia/Kolkata

# Set enviroment and vaiables
DATE="$(date +%d%m%Y-%H%M%S)"
WD=$(pwd)
OUT=${WD}"/out"
CHATID="-1001409962367"
CI_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# The defult directory where the kernel should be placed.
KERNEL_DIR=${WD}

# The name of the Kernel, to name the ZIP.
ZIPNAME="Nexus-Mercenary"

# The name of the device for which the kernel is built.
MODEL="Redmi Note 5 Pro"

# The codename of the device.
DEVICE="whyred"

# The version of the Kernel
VERSION=p1

# Specify toolchain. 'clang' | 'proton-clang'(default) | 'aosp-clang' | 'gcc'
TOOLCHAIN=gcc

# Nexus Kernel Maintainer. 1 is YES | 0 is NO(default)
NEXUS=1

# Set your anykernel3 repo (Required)
AK3_REPO="akirasupr/AnyKernel3"

# The defconfig which should be used. Get it from config.gz from your device or check source
CONFIG="whyred_defconfig"

# File/artifact
IMG=${OUT}"/arch/arm64/boot/Image.gz-dtb"

# Set ccache compilation. 1 = YES | 0 = NO(default)
KERNEL_USE_CCACHE=1

# Specify linker. 'ld.lld'(default)
LINKER=ld.bfd

# Verbose build 0 is Quiet(default)) | 1 is verbose | 2 gives reason for rebuilding targets
VERBOSE=0

# Debug purpose. Send logs on every successfull builds 1 is YES | 0 is NO(default)
LOG_DEBUG=0

# Check Kernel Version
KERVER=$(make kernelversion)

# Set a commit head
COMMIT_HEAD=$(git log --oneline -1)

# shellcheck source=/etc/os-release
DISTRO=$(source /etc/os-release && echo "${NAME}")

# Toolchain Directory defaults
GCC64_DIR=${WD}"/gcc64"
GCC32_DIR=${WD}"/gcc32"
TC_DIR=${WD}"/clang"

# AnyKernel3 Directory default
AK3_DIR=${WD}"/anykernel3"

#-----------------------------------------------------------#

if [[ $TOOLCHAIN == "clang" ]]; then
     git clone --depth=1 https://github.com/theradcolor/clang clang
elif [[ $TOOLCHAIN == "proton-clang" ]]; then
       git clone --depth=1 https://github.com/kdrag0n/proton-clang clang
elif [[ $TOOLCHAIN == "aosp-clang" ]]; then
       git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 gcc64
       git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 gcc32
       mkdir clang
       cd clang || exit
       wget -q https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/master/clang-r416183.tar.gz
       tar -xzf clang*
       cd .. || exit
elif [[ $TOOLCHAIN == "gcc" ]]; then
	   git clone --depth=1 https://github.com/mvaisakh/gcc-arm64.git -b gcc-new gcc64
	   git clone --depth=1 https://github.com/mvaisakh/gcc-arm.git -b gcc-new gcc32
fi
if [[ $NEXUS == "1" ]]; then
     git clone --depth=1 https://github.com/nexus-projects/AnyKernel3.git -b $DEVICE anykernel3
else
     git clone --depth=1 https://github.com/${AK3_REPO}.git anykernel3
fi

#-----------------------------------------------------------#

# Export vaiables
export BOT_MSG_URL="https://api.telegram.org/bot${token}/sendMessage"
export BOT_BUILD_URL="https://api.telegram.org/bot${token}/sendDocument"
export KBUILD_BUILD_VERSION=$DRONE_BUILD_NUMBER
export CI_BRANCH=$DRONE_BRANCH
if [[ $KERNEL_USE_CCACHE == "1" ]]; then
	  export CCACHE_DIR="${KERNEL_DIR}/.ccache"
fi
if [ $VERSION ]
then
	 export LOCALVERSION="-$VERSION"
fi

# Export ARCH <arm, arm64, x86, x86_64>
export ARCH=arm64

#Export SUBARCH <arm, arm64, x86, x86_64>
export SUBARCH=arm64

# Kbuild host and user
export KBUILD_BUILD_USER="akirasupr"
export KBUILD_BUILD_HOST="archlinux"
export KBUILD_JOBS="$(($(grep -c '^processor' /proc/cpuinfo) * 2))"

#-----------------------------------------------------------#

if [[ ${TOOLCHAIN} == "clang" ]]; then
     COMPILER_STRING="$(${TC_DIR}/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' | sed 's/ *$//')"
     export KBUILD_COMPILER_STRING="${COMPILER_STRING}"
     export COMPILER_HEAD_COMMIT=$(cd ${TC_DIR} && git rev-parse HEAD)
     export COMPILER_HEAD_COMMIT_URL="https://github.com/theradcolor/clang/commit/${COMPILER_HEAD_COMMIT}"
elif [[ ${TOOLCHAIN} == "proton-clang" ]]; then
       COMPILER_STRING="$(${TC_DIR}/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' | sed 's/ *$//')"
       export KBUILD_COMPILER_STRING="${COMPILER_STRING}"
       export COMPILER_HEAD_COMMIT=$(cd ${TC_DIR} && git rev-parse HEAD)
       export COMPILER_HEAD_COMMIT_URL="https://github.com/kdrag0n/proton-clang/commit/${COMPILER_HEAD_COMMIT}"
elif [[ ${TOOLCHAIN} == "aosp-clang" ]]; then
       CC="${ccache} $TC_DIR/bin/clang"
       COMPILER_STRING="$(${CC} --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g')"
       export KBUILD_COMPILER_STRING="${COMPILER_STRING}"
elif [[ ${TOOLCHAIN} == "gcc" ]]; then
       export PATH="/drone/src/source/gcc64"/bin/:"/drone/src/source/gcc32"/bin/:/usr/bin:$PATH
       COMPILER_STRING="$(${GCC64_DIR}"/bin/aarch64-elf-gcc" --version | head -n 1)"
       export KBUILD_COMPILER_STRING="${COMPILER_STRING}"
       export COMPILER_HEAD_COMMIT=$(cd ${GCC64_DIR} && git rev-parse HEAD)
       export COMPILER_HEAD_COMMIT_URL="https://github.com/mvaisakh/gcc-arm64/commit/${COMPILER_HEAD_COMMIT}"
fi

#-----------------------------------------------------------#

CAMERA="$(grep 'BLOBS' ${KERNEL_DIR}/arch/arm64/configs/${CONFIG})"
if [ ${CAMERA} == "CONFIG_XIAOMI_NEW_CAMERA_BLOBS=y" ]; then
    export CAM_TYPE="NewCam"
elif [ ${CAMERA} == "CONFIG_XIAOMI_NEW_CAMERA_BLOBS=n" ]; then
    export CAM_TYPE="OldCam"
fi

#-----------------------------------------------------------#

if [ ${TOOLCHAIN} == "gcc" ]; then
     # GCC LTO patches for kernel
     curl https://raw.githubusercontent.com/theradcolor/patches/master/rad-kernel-gcc-lto-patch.patch | git am
     rm -rf *.patch
elif [ ${TOOLCHAIN} == "proton-clang" ]; then
       # CLANG LTO patches for kernel
       curl https://raw.githubusercontent.com/theradcolor/patches/master/rad-kernel-clang-lto-patch.patch | git am
       rm -rf *.patch
fi

#-----------------------------------------------------------#

function post_msg() {
	curl -s -X POST "https://api.telegram.org/bot${token}/sendMessage}" \
    -d chat_id="${CHATID}" \
	-d "disable_web_page_preview=true" \
	-d "parse_mode=html" \
	-d text="$1"
}

#-----------------------------------------------------------#

function post_build() {
    ZIP=$(echo *.zip)
	#Post MD5Checksum alongwith for easeness
	MD5CHECK=$(md5sum "$1" | cut -d' ' -f1)
	#Show the Checksum alongwith caption
	curl -F document=@"${ZIP}" "https://api.telegram.org/bot${token}/sendDocument" \
	-F chat_id="${CHATID}"  \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=html" \
	-F caption="<b>Build took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s).</code>%0a<b>MD5 Checksum : </b><code>$MD5CHECK</code>%0a<b>Compiler : [${COMPILER_STRING}](${COMPILER_HEAD_COMMIT_URL})</a>"
}

#-----------------------------------------------------------#

function post_log() {
    LOG=${KERNEL_DIR}/build.log
    curl -F document=@"${LOG}" "https://api.telegram.org/bot${token}/sendDocument" \
        -F chat_id="${CHATID}" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="<b>Build Logs : </b><code>took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s).</code>%0a<b>MD5 Checksum : </b><code>$MD5CHECK</code>%0a<b>Compiler : [${COMPILER_STRING}](${COMPILER_HEAD_COMMIT_URL})</a>"
}

#-----------------------------------------------------------#

function post_error() {
    LOG=${KERNEL_DIR}/build.log
    curl -F document=@"${LOG}" "https://api.telegram.org/bot${token}/sendDocument" \
        -F chat_id="${CHATID}" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="<b>Build Failed Logs : </b><code>took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s).</code>%0a<b>MD5 Checksum : </b><code>$MD5CHECK</code>%0a<b>Compiler : [${COMPILER_STRING}](${COMPILER_HEAD_COMMIT_URL})</a>"
}

#-----------------------------------------------------------#

post_msg "<b>$KBUILD_BUILD_VERSION CI Build Triggered</b>%0A<b>Docker OS: </b><code>$DISTRO</code>%0A<b>Kernel Version : </b><code>$KERVER</code>%0A<b>Date : </b><code>$(TZ=Asia/Kolkata date)</code>%0A<b>Device : </b><code>$MODEL [$DEVICE]</code>%0A<b>Compiler Used : </b><code>$KBUILD_COMPILER_STRING</code>%0A<b>Linker : </b><code>$LINKER</code>%0a<b>Branch : </b><code>$CI_BRANCH</code>%0A<b>Top Commit : </b><a href='$DRONE_COMMIT_LINK'>$COMMIT_HEAD</a>"

#-----------------------------------------------------------#

if [[ ${TOOLCHAIN} == "clang" ]]; then
     make O="$OUT" ${CONFIG}
     BUILD_START=$(date +"%s")
    make -j"${KBUILD_JOBS}" O=$OUT CC="${TC_DIR}/bin/clang" LLVM_AR="${TC_DIR}/bin/llvm-ar" LLVM_NM="${TC_DIR}/bin/llvm-nm" LD="${TC_DIR}/bin/${LINKER}" OBJCOPY="${TC_DIR}/bin/llvm-objcopy" V="${VERBOSE}" OBJDUMP="${TC_DIR}/bin/llvm-objdump" STRIP="${TC_DIR}/bin/llvm-strip" CROSS_COMPILE="${TC_DIR}/bin/aarch64-linux-gnu-" CROSS_COMPILE_ARM32="${TC_DIR}/bin/arm-linux-gnueabi-" CLANG_TRIPLE=aarch64-linux-gnu- 2>&1 | tee build.log
    BUILD_END=$(date +"%s")
    DIFF=$(($BUILD_END - $BUILD_START))
elif [[ ${TOOLCHAIN} == "proton-clang" ]]; then
       make O="$OUT" ${CONFIG}
       BUILD_START=$(date +"%s")
       make -j"${KBUILD_JOBS}" O=$OUT CC="${TC_DIR}/bin/clang" LLVM_AR="${TC_DIR}/bin/llvm-ar" LLVM_NM="${TC_DIR}/bin/llvm-nm" LD="${TC_DIR}/bin/${LINKER}" OBJCOPY="${TC_DIR}/bin/llvm-objcopy" V="${VERBOSE}" OBJDUMP="${TC_DIR}/bin/llvm-objdump" STRIP="${TC_DIR}/bin/llvm-strip" CROSS_COMPILE="${TC_DIR}/bin/aarch64-linux-gnu-" CROSS_COMPILE_ARM32="${TC_DIR}/bin/arm-linux-gnueabi-" CLANG_TRIPLE=aarch64-linux-gnu- 2>&1 | tee build.log
       BUILD_END=$(date +"%s")
       DIFF=$(($BUILD_END - $BUILD_START))
elif [[ ${TOOLCHAIN} == "aosp-clang" ]]; then
       make O="$OUT" ${CONFIG}
       BUILD_START=$(date +"%s")
       make -j"${KBUILD_JOBS}" O=$OUT ARCH=arm64 CC=$WD"/clang/bin/clang" V="${VERBOSE}" CLANG_TRIPLE="aarch64-linux-gnu-" CROSS_COMPILE=$WD"/gcc64/bin/aarch64-linux-android-" CROSS_COMPILE_ARM32=$WD"/gcc32/bin/arm-linux-androideabi-" 2>&1 | tee build.log
       BUILD_END=$(date +"%s")
       DIFF=$(($BUILD_END - $BUILD_START))
elif [[ ${TOOLCHAIN} == "gcc" ]]; then
       export CROSS_COMPILE=$WD"/gcc64/bin/aarch64-elf-"
       export CROSS_COMPILE_ARM32=$WD"/gcc32/bin/arm-eabi-"
       make O="${OUT}" "${CONFIG}"
       BUILD_START=$(date +"%s")
       make O="${OUT}" CROSS_COMPILE="/drone/src/source/gcc64/bin/aarch64-elf-" CROSS_COMPILE_ARM32="/drone/src/source/gcc32/bin/arm-eabi-" AR=aarch64-elf-ar OBJCOPY=llvm-objcopy OBJDUMP=aarch64-elf-objdump STRIP=aarch64-elf-strip LD=aarch64-elf-${LINKER} NM=llvm-nm V="${VERBOSE}" -j"${KBUILD_JOBS}" 2>&1 | tee build.log
       BUILD_END=$(date +"%s")
       DIFF=$(($BUILD_END - $BUILD_START))
fi

#-----------------------------------------------------------#

if [ -f "${IMG}" ]; then
     echo "Build completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s)."
     cp ${OUT}/arch/arm64/boot/Image.gz-dtb ${AK3_DIR}/
     echo "Now making a flashable zip of kernel with AnyKernel3"
     export ZIP_FINAL=${ZIPNAME}-${VERSION}-${DEVICE}-${DATE}.zip
     cd "${AK3_DIR}" || exit 1
     zip -r9 ${ZIP_FINAL} * -x README.md .git
     post_build
else
     post_error
     echo "Build failed, please fix the errors first bish!"
fi

#-----------------------------------------------------------#

if [[ $LOG_DEBUG == "1" ]]; then
	post_log
fi
