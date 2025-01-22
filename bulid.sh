#!/bin/bash

# ألوان للرسائل
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# دالة لتنظيف الشاشة
clear_screen() {
  clear
}

# تعيين المتغيرات الأساسية
export ARCH=arm64
export TOOLCHAIN=clang-15
export SUBARCH=arm64
export CC=clang-15
export CLANG_PATH="/usr/bin"
export CLANG_TRIPLE=aarch64-linux-gnu-
export CROSS_COMPILE="/usr/bin/aarch64-linux-gnu-"
export CROSS_COMPILE_ARM32="/usr/bin/arm-linux-gnueabi-"
export THREADS="$(grep -c ^processor /proc/cpuinfo)"

# دالة لعرض رسائل الخطأ
error_msg() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# دالة لعرض رسائل التحذير
warning_msg() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

# دالة لعرض رسائل النجاح
success_msg() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# دالة لعرض رسائل المعلومات
info_msg() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

# دالة لتعديل Makefile لوحدة rtl8812au
modify_rtl8812au_makefile() {
  local makefile_path="drivers/rtl8812au/Makefile"
  if [ -f "$makefile_path" ]; then
    info_msg "Modifying rtl8812au Makefile to disable -Wno-stringop-overread..."
    sed -i 's/EXTRA_CFLAGS += -Wno-stringop-overread/#EXTRA_CFLAGS += -Wno-stringop-overread/' "$makefile_path" || {
      error_msg "Failed to modify rtl8812au Makefile."
      return 1
    }
    success_msg "rtl8812au Makefile modified successfully."
  else
    error_msg "rtl8812au Makefile not found."
    return 1
  fi
}

# دالة لتحميل وحدات Wi-Fi من GitHub
download_wifi_drivers() {
  read -p "Do you want to download and install Wi-Fi drivers from GitHub? (y/n): " DOWNLOAD_DRIVERS
  clear_screen
  if [[ $DOWNLOAD_DRIVERS == "y" || $DOWNLOAD_DRIVERS == "Y" ]]; then
    info_msg "Downloading Wi-Fi drivers from GitHub..."

    # إنشاء مجلد drivers إذا لم يكن موجودًا
    mkdir -p drivers

    # تنزيل الوحدات
    git clone https://github.com/aircrack-ng/rtl8188eus.git drivers/rtl8188eus || {
      error_msg "Failed to clone rtl8188eus repository."
      return 1
    }
    git clone https://github.com/kelebek333/rtl8188fu.git drivers/rtl8188fu || {
      error_msg "Failed to clone rtl8188fu repository."
      return 1
    }
    git clone https://github.com/Mange/rtl8192eu-linux-driver.git drivers/rtl8192eu || {
      error_msg "Failed to clone rtl8192eu repository."
      return 1
    }
    git clone https://github.com/kelebek333/rtl8192fu-dkms.git drivers/rtl8192fu || {
      error_msg "Failed to clone rtl8192fu repository."
      return 1
    }
    git clone https://github.com/aircrack-ng/rtl8812au.git drivers/rtl8812au || {
      error_msg "Failed to clone rtl8812au repository."
      return 1
    }
    git clone https://github.com/aircrack-ng/rtl8814au.git drivers/rtl8814au || {
      error_msg "Failed to clone rtl8814au repository."
      return 1
    }

    success_msg "Wi-Fi drivers downloaded successfully."

    # تعديل Makefile لوحدة rtl8812au
    modify_rtl8812au_makefile || return 1

    # إضافة الوحدات إلى Makefile و Kconfig
    info_msg "Adding Wi-Fi drivers to Kernel build system..."

    echo "obj-y += rtl8188eus/" >> drivers/Makefile
    echo "obj-y += rtl8188fu/" >> drivers/Makefile
    echo "obj-y += rtl8192eu/" >> drivers/Makefile
    echo "obj-y += rtl8192fu/" >> drivers/Makefile
    echo "obj-y += rtl8812au/" >> drivers/Makefile
    echo "obj-y += rtl8814au/" >> drivers/Makefile

    echo 'source "drivers/rtl8188eus/Kconfig"' >> drivers/Kconfig
    echo 'source "drivers/rtl8188fu/Kconfig"' >> drivers/Kconfig
    echo 'source "drivers/rtl8192eu/Kconfig"' >> drivers/Kconfig
    echo 'source "drivers/rtl8192fu/Kconfig"' >> drivers/Kconfig
    echo 'source "drivers/rtl8812au/Kconfig"' >> drivers/Kconfig
    echo 'source "drivers/rtl8814au/Kconfig"' >> drivers/Kconfig

    success_msg "Wi-Fi drivers added to Kernel build system successfully."
  else
    info_msg "Skipping Wi-Fi drivers download and installation."
  fi
}

# التحقق من وجود أدوات البناء
check_build_tools() {
  local tools=("clang-15" "make" "git" "python3")
  for tool in "${tools[@]}"; do
    if ! command -v $tool &> /dev/null; then
      error_msg "Tool $tool is not installed."
      return 1
    fi
  done

  success_msg "All required tools are installed."
}

# تثبيت التبعيات المطلوبة
install_dependencies() {
  info_msg "Installing required dependencies..."
  sudo apt update || { error_msg "Failed to update package list"; return 1; }
  sudo apt install -y default-jdk git-core gnupg flex bison gperf build-essential zip curl libc6-dev libncurses-dev x11proto-core-dev libx11-dev libreadline-dev python3 make sudo gcc g++ bc grep tofrodos python3-markdown libxml2-utils xsltproc zlib1g-dev build-essential libncurses-dev bzip2 gcc-arm-linux-gnueabi libssl-dev clang-13 cpio git ccache automake flex lzop bison gperf build-essential zip curl zlib1g-dev libxml2-utils bzip2 libbz2-dev libbz2-1.0 libghc-bzlib-dev squashfs-tools pngcrush schedtool dpkg-dev liblz4-tool make optipng maven libssl-dev pwgen libswitch-perl policycoreutils minicom libxml-sax-base-perl libxml-simple-perl bc x11proto-core-dev libx11-dev libgl1-mesa-dev xsltproc unzip nano python2 || { error_msg "Failed to install dependencies"; return 1; }
  success_msg "Dependencies installed successfully."
}

# تمكين ccache لتسريع البناء
enable_ccache() {
  read -p "Do you want to enable ccache for faster builds? (y/n): " ENABLE_CCACHE
  clear_screen
  if [[ $ENABLE_CCACHE == "y" || $ENABLE_CCACHE == "Y" ]]; then
    if ! command -v ccache &> /dev/null; then
      warning_msg "ccache is not installed. Installing..."
      sudo apt install -y ccache || {
        error_msg "Failed to install ccache."
        return 1
      }
    fi
    export CC="ccache clang-15"
    export CXX="ccache clang++-15"
    success_msg "ccache enabled successfully."
  fi
}

# اختيار ملف التكوين
choose_config() {
  CONFIG_PATH="arch/arm64/configs"
  if [ ! -d "$CONFIG_PATH" ]; then
    error_msg "Directory $CONFIG_PATH does not exist!"
    return 1
  fi

  info_msg "Available configuration files in $CONFIG_PATH:"
  CONFIGS=($(ls $CONFIG_PATH))
  for i in "${!CONFIGS[@]}"; do
    echo "$((i+1)). ${CONFIGS[$i]}"
  done

  while true; do
    read -p "Choose the configuration file number (1-${#CONFIGS[@]}): " CONFIG_NUM
    clear_screen
    if [[ $CONFIG_NUM -ge 1 && $CONFIG_NUM -le ${#CONFIGS[@]} ]]; then
      export CONFIG="${CONFIGS[$((CONFIG_NUM-1))]}"
      success_msg "Selected configuration file: $CONFIG"
      break
    else
      error_msg "Invalid choice! Please try again."
    fi
  done
}

# تهيئة دليل البناء
initialize_build() {
  info_msg "Initializing build directory with configuration $CONFIG..."
  make CC=clang-15 O=out $CONFIG || { error_msg "Failed to initialize build directory"; return 1; }
  success_msg "Build directory initialized successfully."
}

# فتح menuconfig للتعديل (اختياري)
open_menuconfig() {
  read -p "Do you want to open menuconfig to customize the configuration? (y/n): " OPEN_MENUCONFIG
  clear_screen
  if [[ $OPEN_MENUCONFIG == "y" || $OPEN_MENUCONFIG == "Y" ]]; then
    info_msg "Opening menuconfig..."
    make CC=clang-15 O=out menuconfig || { error_msg "Failed to open menuconfig"; return 1; }
    success_msg "Configuration customized successfully."
  fi
}

# بدء عملية البناء
start_build() {
  info_msg "Starting build process with $THREADS threads..."
  make CC=clang-15 ARCH=arm64 O=out -j$THREADS || { error_msg "Build process failed"; return 1; }
  success_msg "Build process completed successfully!"
}

# الدالة الرئيسية
main() {
  clear_screen
  check_build_tools || return 1
  install_dependencies || return 1
  enable_ccache || return 1
  choose_config || return 1
  initialize_build || return 1
  open_menuconfig || return 1
  start_build || return 1
  download_wifi_drivers || return 1
}

# تشغيل الدالة الرئيسية
main
