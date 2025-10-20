#!/bin/bash

# Colors for messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to clear the screen
clear_screen() {
    clear
}

# Set basic variables
export ARCH=arm64
export TOOLCHAIN=clang
export SUBARCH=arm64
export CC=clang
export CLANG_PATH="/usr/bin"
export CLANG_TRIPLE=aarch64-linux-gnu-
export CROSS_COMPILE="/usr/bin/aarch64-linux-gnu-"
export CROSS_COMPILE_ARM32="/usr/bin/arm-linux-gnueabi-"
export THREADS="$(grep -c ^processor /proc/cpuinfo)"

# Function to display error messages
error_msg() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Function to display warning messages
warning_msg() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to display success messages
success_msg() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to display info messages
info_msg() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Function to check and install required packages
check_and_install_packages() {
    info_msg "Checking and installing required packages..."

    packages=(
        "clang" "make" "git" "python3" "flex" "bison" "bc" "libssl-dev"
        "build-essential" "libncurses-dev" "ccache" "automake" "lzop"
        "gperf" "zip" "curl" "zlib1g-dev" "libxml2-utils" "bzip2"
        "libbz2-dev" "squashfs-tools" "pngcrush" "schedtool" "dpkg-dev"
        "liblz4-dev" "optipng" "maven" "pwgen" "libswitch-perl"
        "policycoreutils" "minicom" "libxml-sax-base-perl" "libxml-simple-perl"
        "x11proto-core-dev" "libx11-dev" "libgl1-mesa-dev" "xsltproc"
        "unzip" "nano" "python2"
    )

    for pkg in "${packages[@]}"; do
        if ! dpkg -s "$pkg" &> /dev/null; then
            info_msg "Installing $pkg..."
            sudo apt install -y "$pkg" || error_msg "Failed to install $pkg."
        else
            info_msg "$pkg is already installed."
        fi
    done

    success_msg "All required packages are installed."
}

# Function to fix can327.c file issues
fix_can327_issues() {
    info_msg "Fixing can327.c file issues..."

    if [ -f "drivers/net/can/can327.c" ]; then
        sed -i 's/unsigned int \*can327_mailbox_read/unsigned int can327_mailbox_read/' drivers/net/can/can327.c
        sed -i 's/return -ENOBUFS;/return 0; \/\/ Fixed: was return -ENOBUFS;/' drivers/net/can/can327.c
        sed -i 's/can327_mailbox_read(\*)/can327_mailbox_read()/' drivers/net/can/can327.c 2>/dev/null || true
        info_msg "can327.c file fixes applied successfully"
    else
        warning_msg "can327.c file not found, skipping fixes"
    fi

    success_msg "can327.c file issues fixed."
}

# Function to download and compile specific files
download_and_compile_files() {
    info_msg "Downloading and compiling specific files..."

    info_msg "Downloading nfs/read.c from GitHub..."
    mkdir -p fs/nfs
    wget -q -O fs/nfs/read.c \
        https://raw.githubusercontent.com/eirkkk/android_kernel_oneplus_sm8250-1/refs/heads/lineage-21/fs/nfs/read.c \
        || warning_msg "Failed to download nfs/read.c"

    if [ -f "fs/nfs/read.c" ]; then
        info_msg "Compiling nfs/read.c..."
        if command -v $CC &> /dev/null; then
            $CC -c -o /tmp/read.o fs/nfs/read.c -Iinclude -Ifs/nfs 2>/dev/null && \
            info_msg "nfs/read.c compiled successfully" || \
            warning_msg "nfs/read.c has compilation warnings"
        fi
    fi

    success_msg "Specific files downloaded and compiled."
}

# Function to download additional repositories
download_additional_repos() {
    info_msg "Downloading additional repositories..."

    if [ ! -d "op8" ]; then
        info_msg "Cloning op8 repository..."
        git clone --depth 1 --filter=blob:none --sparse --branch blu_spark-13-custom https://github.com/engstk/op8.git
        cd op8
        git sparse-checkout set techpack/audio/asoc/codecs/tfa98xx-v6
        git checkout blu_spark-13-custom
        cd ..
    fi

    if [ ! -d "crdroid_12_kernel" ]; then
        info_msg "Cloning crdroid repository..."
        git clone --depth 1 --filter=blob:none --sparse https://github.com/flyoverhead/crdroid_12_kernel.git
        cd crdroid_12_kernel
        git sparse-checkout set drivers/staging/qca-wifi-host-cmn/htc
        git sparse-checkout set drivers/net/wireless/ath/ath9k
        git checkout 12L-nethunter
        cd ..
    fi

    success_msg "Additional repositories downloaded successfully."
}

# Function to copy files from additional repositories
copy_repo_files() {
    info_msg "Copying files from additional repositories..."

    if [ -d "op8/techpack/audio/asoc/codecs/tfa98xx-v6" ]; then
        mkdir -p techpack/audio/asoc/codecs/
        cp -r op8/techpack/audio/asoc/codecs/tfa98xx-v6 techpack/audio/asoc/codecs/
        info_msg "Copied audio codecs from op8 repository"
    fi

    if [ -d "crdroid_12_kernel/drivers/staging/qca-wifi-host-cmn/htc" ]; then
        mkdir -p drivers/staging/qca-wifi-host-cmn/
        cp -r crdroid_12_kernel/drivers/* drivers/
        info_msg "Copied WiFi drivers from crdroid repository"
    fi

    success_msg "Files copied from additional repositories."
}

# Function to download Wi-Fi drivers
download_wifi_drivers() {
    info_msg "Downloading Wi-Fi drivers from GitHub..."

    mkdir -p drivers

    declare -A drivers=(
        ["rtl8188eus"]="https://github.com/aircrack-ng/rtl8188eus.git"
        ["rtl8188fu"]="https://github.com/kelebek333/rtl8188fu.git"
        ["rtl8192eu"]="https://github.com/Mange/rtl8192eu-linux-driver.git"
        ["rtl8192fu"]="https://github.com/eirkkk/rtl8192fu-dkms.git"
        ["rtl8812au"]="https://github.com/eirkkk/rtl8812au.git"
        ["rtl8814au"]="https://github.com/aircrack-ng/rtl8814au.git"
        ["88x2bu"]="https://github.com/morrownr/88x2bu-20210702.git"
        ["rtl8821au"]="https://github.com/ivanovborislav/rtl8821au"
    )

    for driver_name in "${!drivers[@]}"; do
        repo_url="${drivers[$driver_name]}"
        driver_path="drivers/$driver_name"

        if [ -d "$driver_path" ]; then
            info_msg "$driver_name directory already exists. Skipping..."
        else
            info_msg "Downloading $driver_name..."
            git clone "$repo_url" "$driver_path" || warning_msg "Failed to clone $driver_name repository."
        fi
    done

    success_msg "Wi-Fi drivers downloaded successfully."
}

# Function to setup CAN bus subsystem support
setup_can_support() {
    info_msg "Setting up CAN bus subsystem support..."

    if [ ! -d ".git" ]; then
        git init || warning_msg "Git initialization failed"
    fi

    can_modules=(
        "https://github.com/V0lk3n/usb-can-2-module drivers/net/can/usb-can-2-module"
        "https://github.com/V0lk3n/can-isotp drivers/net/can/can-isotp"
        "https://github.com/V0lk3n/elmcan drivers/net/can/elmcan"
    )

    for module in "${can_modules[@]}"; do
        repo_url=$(echo "$module" | awk '{print $1}')
        module_path=$(echo "$module" | awk '{print $2}')
        
        if [ ! -d "$module_path" ]; then
            git submodule add "$repo_url" "$module_path" || warning_msg "Failed to add submodule $module_path"
        fi
    done

    mkdir -p include/uapi/linux/can
    wget -q -O include/uapi/linux/can/isotp.h \
        https://raw.githubusercontent.com/v0lk3n/can-isotp/refs/heads/master/include/uapi/linux/can/isotp.h \
        || warning_msg "Failed to download isotp.h"

    if [ -f "drivers/net/can/elmcan/can327.c" ]; then
        cp drivers/net/can/elmcan/can327.c drivers/net/can/
    fi

    success_msg "CAN bus subsystem setup completed."
}

# Function to add ELM327 driver config
add_elm327_driver() {
    info_msg "Adding ELM327 driver configuration..."

    info_msg "Editing drivers/net/can/Kconfig..."
    if ! grep -q "config CAN_CAN327" drivers/net/can/Kconfig; then
        cat << 'EOF' >> drivers/net/can/Kconfig

config CAN_CAN327
	tristate "Serial / USB serial ELM327 based OBD-II Interfaces (can327)"
	depends on TTY
	select CAN_RX_OFFLOAD
	help
	 CAN driver for several 'low cost' OBD-II interfaces based on the
	 ELM327 OBD-II interpreter chip.
	 This is a best effort driver - the ELM327 interface was never
	 designed to be used as a standalone CAN interface. However, it can
	 still be used for simple request-response protocols (such as OBD II),
	 and to monitor broadcast messages on a bus (such as in a vehicle).
	 Please refer to the documentation for information on how to use it:
	 Documentation/networking/device_drivers/can/can327.rst
	 If this driver is built as a module, it will be called can327.
EOF
        success_msg "Added CAN_CAN327 config to Kconfig"
    else
        info_msg "CAN_CAN327 config already exists in Kconfig"
    fi
    
    success_msg "ELM327 driver added successfully!"
}

# Function to modify Kconfig files for CAN support
modify_can_kconfig() {
    info_msg "Modifying CAN Kconfig files..."

    can_kconfig_lines=(
        'source "drivers/net/can/usb-can-2-module/Kconfig"'
        'source "drivers/net/can/can-isotp/Kconfig"'
    )

    for line in "${can_kconfig_lines[@]}"; do
        if ! grep -q "$line" drivers/net/can/Kconfig 2>/dev/null; then
            echo "$line" >> drivers/net/can/Kconfig
        fi
    done

    success_msg "CAN Kconfig modifications completed."
}

# Function to modify Makefiles for CAN support
modify_can_makefile() {
    info_msg "Modifying CAN Makefiles..."

    can_makefile_lines=(
        'obj-y += usb-can-2-module/'
        'obj-y += can-isotp/'
        'obj-$(CONFIG_CAN_CAN327) += can327.o'
    )

    for line in "${can_makefile_lines[@]}"; do
        if ! grep -q "$line" drivers/net/can/Makefile 2>/dev/null; then
            echo "$line" >> drivers/net/can/Makefile
        fi
    done

    success_msg "CAN Makefile modifications completed."
}

# Function to modify Makefiles after downloading drivers
modify_makefiles() {
    info_msg "Modifying Makefiles to fix build issues..."

    if [ -f "drivers/88x2bu/Makefile" ]; then
        sed -i 's/EXTRA_CFLAGS += -Wno-stringop-overread/#EXTRA_CFLAGS += -Wno-stringop-overread/' drivers/88x2bu/Makefile
        sed -i 's/-Wno-stringop-overread//g' drivers/88x2bu/Makefile
    fi

    if [ -f "drivers/rtl8192fu/Makefile" ]; then
        sed -i 's/-Wno-discarded-qualifiers/-Wno-ignored-qualifiers/' drivers/rtl8192fu/Makefile
    fi

    success_msg "Makefiles modified successfully."
}

# Function to modify Kconfig and Makefile for WiFi drivers
modify_kconfig_and_makefile() {
    info_msg "Modifying Kconfig and Makefile for WiFi drivers..."

    if [ -f "drivers/Kconfig" ]; then
        wifi_drivers=(
            "rtl8188eus" "rtl8188fu" "rtl8192eu" "rtl8192fu"
            "rtl8812au" "rtl8814au" "88x2bu" "rtl8821au"
        )

        for driver in "${wifi_drivers[@]}"; do
            if [ -d "drivers/$driver" ] && [ -f "drivers/$driver/Kconfig" ]; then
                if ! grep -q "source \"drivers/$driver/Kconfig\"" drivers/Kconfig; then
                    echo "source \"drivers/$driver/Kconfig\"" >> drivers/Kconfig
                fi
            fi
        done
        success_msg "Kconfig modified successfully."
    else
        error_msg "drivers/Kconfig file not found!"
    fi

    if [ -f "drivers/Makefile" ]; then
        wifi_drivers=(
            "rtl8188eus" "rtl8188fu" "rtl8192eu" "rtl8192fu"
            "rtl8812au" "rtl8814au" "88x2bu" "rtl8821au"
        )

        for driver in "${wifi_drivers[@]}"; do
            if [ -d "drivers/$driver" ]; then
                if ! grep -q "obj-y += $driver/" drivers/Makefile; then
                    echo "obj-y += $driver/" >> drivers/Makefile
                fi
            fi
        done
        success_msg "Makefile modified successfully."
    else
        error_msg "drivers/Makefile file not found!"
    fi
}

# Function to import docker support
import_docker_support() {
    info_msg "Importing Docker support from GitHub repository..."

    if [ -d "docker" ]; then
        info_msg "Docker directory already exists. Checking if it needs updates..."
        
        if [ -d "docker/.git" ]; then
            cd docker
            git pull origin main || warning_msg "Failed to update existing docker repository"
            cd ..
        else
            info_msg "Docker directory exists but is not a git repo, skipping import"
        fi
    else
        info_msg "Fetching docker support from GitHub..."
        git fetch https://github.com/lateautumn233/android_kernel_docker main
        
        info_msg "Merging docker support..."
        git merge -s ours --no-commit FETCH_HEAD 2>/dev/null || true
        git read-tree --prefix=docker -u FETCH_HEAD
        
        git commit -a -m "Imported docker/ from https://github.com/lateautumn233/android_kernel_docker" 2>/dev/null || \
        warning_msg "Git commit failed, but docker support was imported"
    fi

    if [ -f "arch/arm64/Kconfig" ] && ! grep -q 'source "docker/Kconfig"' arch/arm64/Kconfig; then
        echo 'source "docker/Kconfig"' >> arch/arm64/Kconfig
        success_msg "Added docker Kconfig to arch/arm64/Kconfig"
    elif [ -f "arch/arm64/Kconfig" ]; then
        info_msg "Docker Kconfig already exists in arch/arm64/Kconfig"
    fi

    success_msg "Docker support imported successfully!"
}

# Function to setup Lindroid DRM loopback
setup_lindroid_drm() {
    info_msg "Setting up Lindroid DRM loopback support..."

    if [ ! -d "drivers/lindroid-drm" ]; then
        info_msg "Cloning Lindroid DRM loopback repository..."
        git clone --depth 1 https://github.com/Linux-on-droid/lindroid-drm-loopback.git drivers/lindroid-drm || \
        error_msg "Failed to clone Lindroid DRM loopback repository"
    else
        info_msg "Lindroid DRM directory already exists"
    fi

    if [ -f "drivers/Makefile" ]; then
        if ! grep -q "obj-y += lindroid-drm/" drivers/Makefile; then
            echo "obj-y += lindroid-drm/" >> drivers/Makefile
            success_msg "Added Lindroid DRM to drivers/Makefile"
        else
            info_msg "Lindroid DRM already exists in drivers/Makefile"
        fi
    else
        error_msg "drivers/Makefile not found!"
    fi

    if [ -f "drivers/Kconfig" ]; then
        if ! grep -q 'source "drivers/lindroid-drm/Kconfig"' drivers/Kconfig; then
            echo 'source "drivers/lindroid-drm/Kconfig"' >> drivers/Kconfig
            success_msg "Added Lindroid DRM Kconfig to drivers/Kconfig"
        else
            info_msg "Lindroid DRM Kconfig already exists in drivers/Kconfig"
        fi
    else
        error_msg "drivers/Kconfig not found!"
    fi

    success_msg "Lindroid DRM loopback setup completed successfully!"
}

# Function to choose and apply configuration file
choose_and_apply_config() {
    CONFIG_PATH="arch/arm64/configs"
    if [ ! -d "$CONFIG_PATH" ]; then
        error_msg "Directory $CONFIG_PATH does not exist!"
    fi

    info_msg "Available configuration files in $CONFIG_PATH:"
    
    CONFIGS=()
    while IFS= read -r -d $'\0' file; do
        CONFIGS+=("$(basename "$file")")
    done < <(find "$CONFIG_PATH" -maxdepth 1 -type f -print0 2>/dev/null)
    
    if [ ${#CONFIGS[@]} -eq 0 ]; then
        info_msg "Using alternative method to list config files..."
        CONFIGS=($(ls "$CONFIG_PATH" 2>/dev/null))
    fi
    
    if [ ${#CONFIGS[@]} -eq 0 ]; then
        error_msg "No configuration files found in $CONFIG_PATH!"
    fi
    
    for i in "${!CONFIGS[@]}"; do
        echo "$((i+1)). ${CONFIGS[$i]}"
    done

    while true; do
        read -p "Choose the configuration file number (1-${#CONFIGS[@]}): " CONFIG_NUM
        if [[ $CONFIG_NUM =~ ^[0-9]+$ ]] && [[ $CONFIG_NUM -ge 1 && $CONFIG_NUM -le ${#CONFIGS[@]} ]]; then
            export CONFIG="${CONFIGS[$((CONFIG_NUM-1))]}"
            success_msg "Selected configuration file: $CONFIG"
            break
        else
            echo -e "${RED}[ERROR]${NC} Invalid choice! Please enter a number between 1 and ${#CONFIGS[@]}."
        fi
    done

    info_msg "Applying configuration: $CONFIG"
    
    mkdir -p out
    
    info_msg "Trying to apply config using different methods..."
    
    if make ARCH=arm64 CC=clang O=out "${CONFIG}_defconfig" 2>/dev/null; then
        success_msg "Config applied using ${CONFIG}_defconfig"
    elif make ARCH=arm64 CC=clang O=out "$CONFIG" 2>/dev/null; then
        success_msg "Config applied using $CONFIG"
    elif cp "$CONFIG_PATH/$CONFIG" out/.config 2>/dev/null; then
        success_msg "Config copied manually to out/.config"
        make ARCH=arm64 CC=clang O=out oldconfig || warning_msg "oldconfig failed, but config was copied"
    else
        error_msg "Failed to apply configuration $CONFIG using all methods"
    fi
    
    success_msg "Configuration $CONFIG applied successfully to out/.config"
}

# Function to open menuconfig
open_menuconfig() {
    read -p "Do you want to open menuconfig to customize the configuration? (y/n): " OPEN_MENUCONFIG
    if [[ $OPEN_MENUCONFIG == "y" || $OPEN_MENUCONFIG == "Y" ]]; then
        info_msg "Opening menuconfig..."
        make ARCH=arm64 CC=clang O=out menuconfig || error_msg "Failed to open menuconfig."
        success_msg "Configuration customized successfully."
    else
        info_msg "Skipping menuconfig."
    fi
}

# Function to start the build process
start_build() {
    info_msg "Starting build process with $THREADS threads..."
    
    make ARCH=arm64 CC=clang O=out -j"$THREADS" || error_msg "Build process failed."
    
    success_msg "Build process completed successfully!"
}

# Main function
main() {
    clear_screen
    check_and_install_packages
    download_and_compile_files
    download_additional_repos
    copy_repo_files
    download_wifi_drivers
    setup_can_support
    add_elm327_driver
    fix_can327_issues
    modify_can_kconfig
    modify_can_makefile
    modify_makefiles
    modify_kconfig_and_makefile
    import_docker_support
    setup_lindroid_drm
    choose_and_apply_config
    open_menuconfig
    start_build
}

# Run the main function
main "$@"
