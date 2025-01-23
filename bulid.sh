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

  # List of required packages
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

# Function to download Wi-Fi drivers
download_wifi_drivers() {
  info_msg "Downloading Wi-Fi drivers from GitHub..."

  # Create drivers directory if it doesn't exist
  mkdir -p drivers

  # List of drivers to download
  drivers=(
    "rtl8188eus https://github.com/aircrack-ng/rtl8188eus.git"
    "rtl8188fu https://github.com/kelebek333/rtl8188fu.git"
    "rtl8192eu https://github.com/Mange/rtl8192eu-linux-driver.git"
    "rtl8192fu https://github.com/eirkkk/rtl8192fu-dkms.git"
    "rtl8812au https://github.com/eirkkk/rtl8812au.git"
    "rtl8814au https://github.com/aircrack-ng/rtl8814au.git"
    "88x2bu https://github.com/morrownr/88x2bu-20210702.git"
  )

  for driver in "${drivers[@]}"; do
    driver_name=$(echo "$driver" | awk '{print $1}')
    repo_url=$(echo "$driver" | awk '{print $2}')
    driver_path="drivers/$driver_name"

    if [ -d "$driver_path" ]; then
      info_msg "$driver_name directory already exists. Skipping..."
    else
      info_msg "Downloading $driver_name..."
      git clone "$repo_url" "$driver_path" || error_msg "Failed to clone $driver_name repository."
    fi
  done

  success_msg "Wi-Fi drivers downloaded successfully."
}

# Function to modify Makefiles after downloading drivers
modify_makefiles() {
  info_msg "Modifying Makefiles to fix build issues..."

  # Disable unsupported warning options
  sed -i 's/EXTRA_CFLAGS += -Wno-stringop-overread/#EXTRA_CFLAGS += -Wno-stringop-overread/' drivers/88x2bu/Makefile
  sed -i 's/-Wno-discarded-qualifiers/-Wno-ignored-qualifiers/' drivers/rtl8192fu/Makefile

  success_msg "Makefiles modified successfully."
}

# Function to modify Kconfig and Makefile
modify_kconfig_and_makefile() {
  info_msg "Modifying Kconfig and Makefile..."

  # Append to Kconfig
  if [ -f "drivers/Kconfig" ]; then
    echo 'source "drivers/rtl8188eus/Kconfig"' >> drivers/Kconfig
    echo 'source "drivers/rtl8188fu/Kconfig"' >> drivers/Kconfig
    echo 'source "drivers/rtl8192eu/Kconfig"' >> drivers/Kconfig
    echo 'source "drivers/rtl8192fu/Kconfig"' >> drivers/Kconfig
    echo 'source "drivers/rtl8812au/Kconfig"' >> drivers/Kconfig
    echo 'source "drivers/rtl8814au/Kconfig"' >> drivers/Kconfig
    echo 'source "drivers/88x2bu/Kconfig"' >> drivers/Kconfig
    success_msg "Kconfig modified successfully."
  else
    error_msg "drivers/Kconfig file not found!"
  fi

  # Append to Makefile
  if [ -f "drivers/Makefile" ]; then
    echo 'obj-y += rtl8188eus/' >> drivers/Makefile
    echo 'obj-y += rtl8188fu/' >> drivers/Makefile
    echo 'obj-y += rtl8192eu/' >> drivers/Makefile
    echo 'obj-y += rtl8192fu/' >> drivers/Makefile
    echo 'obj-y += rtl8812au/' >> drivers/Makefile
    echo 'obj-y += rtl8814au/' >> drivers/Makefile
    echo 'obj-y += 88x2bu/' >> drivers/Makefile
    success_msg "Makefile modified successfully."
  else
    error_msg "drivers/Makefile file not found!"
  fi
}

# Function to choose configuration file
choose_config() {
  CONFIG_PATH="arch/arm64/configs"
  if [ ! -d "$CONFIG_PATH" ]; then
    error_msg "Directory $CONFIG_PATH does not exist!"
  fi

  info_msg "Available configuration files in $CONFIG_PATH:"
  CONFIGS=($(ls "$CONFIG_PATH"))
  for i in "${!CONFIGS[@]}"; do
    echo "$((i+1)). ${CONFIGS[$i]}"
  done

  while true; do
    read -p "Choose the configuration file number (1-${#CONFIGS[@]}): " CONFIG_NUM
    if [[ $CONFIG_NUM -ge 1 && $CONFIG_NUM -le ${#CONFIGS[@]} ]]; then
      export CONFIG="${CONFIGS[$((CONFIG_NUM-1))]}"
      success_msg "Selected configuration file: $CONFIG"
      break
    else
      error_msg "Invalid choice! Please try again."
    fi
  done
}

# Function to open menuconfig
open_menuconfig() {
  read -p "Do you want to open menuconfig to customize the configuration? (y/n): " OPEN_MENUCONFIG
  if [[ $OPEN_MENUCONFIG == "y" || $OPEN_MENUCONFIG == "Y" ]]; then
    info_msg "Opening menuconfig..."
    make CC="$CC" O=out menuconfig || error_msg "Failed to open menuconfig."
    success_msg "Configuration customized successfully."
  else
    info_msg "Skipping menuconfig."
  fi
}

# Function to start the build process
start_build() {
  info_msg "Starting build process with $THREADS threads..."
  make CC="$CC" ARCH="$ARCH" O=out -j"$THREADS" || error_msg "Build process failed."
  success_msg "Build process completed successfully!"
}

# Main function
main() {
  clear_screen
  check_and_install_packages
  download_wifi_drivers
  modify_makefiles
  modify_kconfig_and_makefile
  choose_config
  open_menuconfig
  start_build
}

# Run the main function
main
