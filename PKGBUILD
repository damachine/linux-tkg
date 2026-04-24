# Based on the file created for Arch Linux by:
# Tobias Powalowski <tpowa@archlinux.org>
# Thomas Baechler <thomas@archlinux.org>

# Contributor: Tk-Glitch <ti3nou at gmail dot com>
# Contributor: Hyper-KVM <hyperkvmx86 at gmail dot com>

plain '       .---.`               `.---.'
plain '    `/syhhhyso-           -osyhhhys/`'
plain '   .syNMdhNNhss/``.---.``/sshNNhdMNys.'
plain '   +sdMh.`+MNsssssssssssssssNM+`.hMds+'
plain '   :syNNdhNNhssssssssssssssshNNhdNNys:'
plain '    /ssyhhhysssssssssssssssssyhhhyss/'
plain '    .ossssssssssssssssssssssssssssso.'
plain '   :sssssssssssssssssssssssssssssssss:'
plain '  /sssssssssssssssssssssssssssssssssss/   Linux-tkg'
plain ' :sssssssssssssoosssssssoosssssssssssss:        kernels'
plain ' osssssssssssssoosssssssoossssssssssssso'
plain ' osssssssssssyyyyhhhhhhhyyyyssssssssssso'
plain ' /yyyyyyhhdmmmmNNNNNNNNNNNmmmmdhhyyyyyy/'
plain '  smmmNNNNNNNNNNNNNNNNNNNNNNNNNNNNNmmms'
plain '   /dNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNd/'
plain '    `:sdNNNNNNNNNNNNNNNNNNNNNNNNNds:`'
plain '       `-+shdNNNNNNNNNNNNNNNdhs+-`'
plain '             `.-:///////:-.`'

_where="$PWD" # track basedir as different Arch based distros are moving srcdir around

# Create BIG_UGLY_FROGMINER only on first run and save in it all settings
if [ ! -e "$_where"/BIG_UGLY_FROGMINER ]; then

  cp "$_where"/customization.cfg "$_where"/BIG_UGLY_FROGMINER
  echo >> "$_where"/BIG_UGLY_FROGMINER

  # extract and define value of _EXT_CONFIG_PATH from customization file
  if [[ -z "$_EXT_CONFIG_PATH" ]]; then
    eval `grep _EXT_CONFIG_PATH "$_where"/customization.cfg`
  fi

  if [ -f "$_EXT_CONFIG_PATH" ]; then
    msg2 "External configuration file $_EXT_CONFIG_PATH will be used and will override customization.cfg values."
    cat "$_EXT_CONFIG_PATH" >> "$_where"/BIG_UGLY_FROGMINER
    echo >> "$_where"/BIG_UGLY_FROGMINER
  fi

  declare -p -x >> "$_where"/BIG_UGLY_FROGMINER

  echo -e "_ispkgbuild=\"true\"\n_distro=\"Arch\"\n_where=\"$PWD\"" >> "$_where"/BIG_UGLY_FROGMINER

  source "$_where"/BIG_UGLY_FROGMINER
  source "$_where"/linux-tkg-config/prepare

  _tkg_initscript
fi

source "$_where"/BIG_UGLY_FROGMINER
source "$_where"/linux-tkg-config/prepare

if [ -n "$_custom_pkgbase" ]; then
  pkgbase="${_custom_pkgbase}"
else
  pkgbase=linux"${_basever}"-tkg-"${_cpusched}"${_compiler_name}
fi
pkgname=("${pkgbase}" "${pkgbase}-headers")
[ "$_nvidia_open" != "false" ] && [ -n "$_nvidia_open" ] && pkgname+=("${pkgbase}-nvidia-open") # Separate package for open NVIDIA kernel modules, built alongside the main kernel package.
pkgver="${_basekernel}"."${_sub}"
pkgrel=8086
pkgdesc='Linux-tkg'
arch=('x86_64') # no i686 in here
url="https://www.kernel.org/"
license=('GPL-2.0-only')
makedepends=(
  bc
  binutils
  cpio
  gettext
  glibc
  libelf
  libgcc
  openssl
  pahole
  perl
  python
  rust
  rust-bindgen
  rust-src
  tar
  xxhash
  xz
  zlib
  zstd
)
if [ "$_compiler_name" = "-llvm" ]; then
  makedepends+=('clang' 'llvm' 'lld')
fi

# nvidia-open source tarball — vulkan-beta from GitHub with fallback mirrors
if [ "$_nvidia_open" != "false" ] && [ -n "$_nvidia_open" ]; then
  if [ "$_nvidia_open" = "vulkan" ]; then
    _nv_open_pkg="open-gpu-kernel-modules-${_nvidia_open_version}"
    source+=("${_nv_open_pkg}.tar.gz::https://github.com/NVIDIA/open-gpu-kernel-modules/archive/refs/tags/${_nvidia_open_version}.tar.gz")
  else
    _nv_open_pkg="NVIDIA-kernel-module-source-${_nvidia_open_version}"
    source+=("https://download.nvidia.com/XFree86/NVIDIA-kernel-module-source/${_nv_open_pkg}.tar.xz")
  fi
  sha256sums+=('SKIP')
fi
optdepends=('schedtool')
options=('!strip' 'docs')

for f in "$_where"/linux-tkg-config/"$_basekernel"/* "$_where"/linux-tkg-patches/"$_basekernel"/*.patch; do
  source+=( "$f" )
  sha256sums+=( "SKIP" )
done

export KBUILD_BUILD_HOST=archlinux
export KBUILD_BUILD_USER=$pkgbase
export KBUILD_BUILD_TIMESTAMP="$(date -Ru${SOURCE_DATE_EPOCH:+d @$SOURCE_DATE_EPOCH})"

prepare() {
  source "$_where"/BIG_UGLY_FROGMINER
  source "$_where"/linux-tkg-config/prepare

  rm -rf $pkgdir # Nuke the entire pkg folder so it'll get regenerated clean on next build

  ln -s "${_kernel_work_folder_abs}" "${srcdir}"

  _tkg_srcprep

  _module_drv_clone
}

build() {
  source "$_where"/BIG_UGLY_FROGMINER

  # Derive _nv_open_pkg here in case it wasn't set at PKGBUILD load time
  # (happens on fresh builds where _nvidia_open was empty in customization.cfg)
  if [ -z "$_nv_open_pkg" ] && [ "$_nvidia_open" != "false" ] && [ -n "$_nvidia_open" ]; then
    if [ "$_nvidia_open" = "vulkan" ]; then
      _nv_open_pkg="open-gpu-kernel-modules-${_nvidia_open_version}"
    else
      _nv_open_pkg="NVIDIA-kernel-module-source-${_nvidia_open_version}"
    fi
  fi

  cd "$_kernel_work_folder_abs"

  # Use custom compiler paths if defined
  if [ "$_compiler_name" = "-llvm" ] && [ -n "${CUSTOM_LLVM_PATH}" ]; then
    PATH="${CUSTOM_LLVM_PATH}/bin:${CUSTOM_LLVM_PATH}/lib:${CUSTOM_LLVM_PATH}/include:${PATH}"
  elif [ -n "${CUSTOM_GCC_PATH}" ]; then
    PATH="${CUSTOM_GCC_PATH}/bin:${CUSTOM_GCC_PATH}/lib:${CUSTOM_GCC_PATH}/include:${PATH}"
  fi

  if [ "$_force_all_threads" = "true" ]; then
    _force_all_threads="-j$((`nproc`+1))"
  else
    _force_all_threads="${MAKEFLAGS}"
  fi

  # ccache
  if [ "$_noccache" != "true" ] && pacman -Qq ccache &> /dev/null; then
    export PATH="/usr/lib/ccache/bin/:$PATH"
    export CCACHE_SLOPPINESS="file_macro,locale,time_macros"
    export CCACHE_NOHASHDIR="true"
    msg2 'ccache was found and will be used'
  fi

  # document the TkG variables, excluding "_", "_EXT_CONFIG_PATH", "_where", and "_path".
  declare -p | cut -d ' ' -f 3 | grep -P '^_(?!=|EXT_CONFIG_PATH|where|path)' > "${srcdir}/customization-full.cfg"

  # remove -O2 flag and place user optimization flag
  CFLAGS=${CFLAGS/-O2/}
  CFLAGS+=" ${_compileropt}"
  # AutoFDO profile flag
  local _autofdo_make_flag=""
  if [[ -n "$_autofdo_profile_path" && -f "$_autofdo_profile_path" ]]; then
    _autofdo_make_flag="CLANG_AUTOFDO_PROFILE=${_autofdo_profile_path}"
    msg2 "AutoFDO: using profile ${_autofdo_profile_path}"
  fi
  # build!
  if pacman -Qq schedtool &> /dev/null; then
    msg2 "Using schedtool"
    _schedtool="command schedtool -B -n 1"
    _ionice="command ionice -n 1"
  fi
  _runtime=$(
    if [ -n "$_schedtool" ]; then
      _pid="$(exec bash -c 'echo "$PPID"')"
      $_schedtool "$_pid" ||:
      $_ionice -p "$_pid" ||:
    fi

    export KCPPFLAGS
    export KCFLAGS
    export KRUSTFLAGS

    time ( make ${_force_all_threads} ${llvm_opt} ${_autofdo_make_flag} LOCALVERSION= bzImage modules 2>&1 ) 3>&1 1>&2 2>&3
    return 0
  )

  # Build nvidia-open modules after the kernel build produced its output tree.
  if [ "$_nvidia_open" != "false" ] && [ -n "$_nvidia_open" ]; then
    local _nv_open_src="${srcdir}/${_nv_open_pkg}"
    local _kernuname
    _kernuname="$(< "${_kernel_work_folder_abs}/include/config/kernel.release")"
    local MODULE_FLAGS=(
      KERNEL_UNAME="${_kernuname}"
      IGNORE_PREEMPT_RT_PRESENCE=1
      SYSSRC="${_kernel_work_folder_abs}"
      SYSOUT="${_kernel_work_folder_abs}"
      IGNORE_CC_MISMATCH=yes
    )
    if [ ! -d "${_nv_open_src}" ]; then
      error "NVIDIA-open source directory not found: ${_nv_open_src}"
      exit 1
    fi
    msg2 "Building NVIDIA open kernel modules (${_nvidia_open_version})..."
    CFLAGS= CXXFLAGS= LDFLAGS= make "${BUILD_FLAGS[@]}" "${MODULE_FLAGS[@]}" \
      -C "${_nv_open_src}" -j"$(nproc)" modules
  fi

  _module_drv_build
}

# Shared helper: resolve kernel sign-file, key, cert and hash from .config
_resolve_signing_params() {
  if ! grep -q 'CONFIG_MODULE_SIG=y' "${_kernel_work_folder_abs}/.config"; then
    warning "Module signing was requested but CONFIG_MODULE_SIG=y is not set in .config — skipping."
    return 1
  fi

  _sign_script="${_kernel_work_folder_abs}/scripts/sign-file"
  _sign_key="$(grep -Po 'CONFIG_MODULE_SIG_KEY="\K[^"]*' "${_kernel_work_folder_abs}/.config")"
  [[ "$_sign_key" =~ ^/ ]] || _sign_key="${_kernel_work_folder_abs}/${_sign_key}"
  _sign_cert="${_kernel_work_folder_abs}/certs/signing_key.x509"
  _sign_hash="$(grep -Po 'CONFIG_MODULE_SIG_HASH="\K[^"]*' "${_kernel_work_folder_abs}/.config")"

  if [[ ! -f "$_sign_key" ]]; then
    warning "Module signing key not found: ${_sign_key}"
    return 1
  elif [[ ! -f "$_sign_cert" ]]; then
    warning "Module signing certificate not found: ${_sign_cert}"
    return 1
  fi

  return 0
}

hackbase() {
  source "$_where"/BIG_UGLY_FROGMINER

  pkgdesc="The $pkgdesc kernel and modules - https://github.com/Frogging-Family/linux-tkg"
  depends=('coreutils' 'kmod' 'initramfs')
  optdepends=('linux-docs: Kernel hackers manual - HTML documentation that comes with the Linux kernel.'
              'crda: to set the correct wireless channels of your country.'
              'linux-firmware: Firmware files for Linux'
              'modprobed-db: Keeps track of EVERY kernel module that has ever been probed. Useful for make localmodconfig.'
              'nvidia-tkg: NVIDIA drivers for all installed kernels - non-dkms version.'
              'nvidia-dkms-tkg: NVIDIA drivers for all installed kernels - dkms version.'
              'update-grub: Simple wrapper around grub-mkconfig.'
              'scx-scheds: to use sched-ext schedulers')
  if [ -e "${srcdir}/ntsync.rules" ]; then
    provides=("linux=${pkgver}" "${pkgbase}" KSMBD-MODULE VIRTUALBOX-GUEST-MODULES WIREGUARD-MODULE NTSYNC-MODULE ntsync-header)
  else
    provides=("linux=${pkgver}" "${pkgbase}" KSMBD-MODULE VIRTUALBOX-GUEST-MODULES WIREGUARD-MODULE)
  fi
  [[ "$_module_drv" == *v4l2loopback* ]] && provides+=(V4L2LOOPBACK-MODULE)
  replaces=(virtualbox-guest-modules-arch wireguard-arch)

  cd "$_kernel_work_folder_abs"

  # get kernel version
  local _kernver="$(<version)"
  local modulesdir="$pkgdir/usr/lib/modules/$_kernver"

  msg2 "Installing boot image..."
  # systemd expects to find the kernel here to allow hibernation
  # https://github.com/systemd/systemd/commit/edda44605f06a41fb86b7ab8128dcf99161d2344
  install -Dm644 "$(make ${llvm_opt} -s image_name)" "$modulesdir/vmlinuz"

  # Used by mkinitcpio to name the kernel
  echo "$pkgbase" | install -Dm644 /dev/stdin "$modulesdir/pkgbase"

  msg2 "Installing modules..."

  local _STRIP_MODS=""
  [[ "$_STRIP" == "true" ]] && _STRIP_MODS="INSTALL_MOD_STRIP=1"

  ZSTD_CLEVEL=19 make ${llvm_opt} INSTALL_MOD_PATH="$pkgdir/usr" $_STRIP_MODS \
    DEPMOD=/doesnt/exist modules_install  # Suppress depmod

  # remove build and source links
  rm -f "$modulesdir"/{source,build}

  # Re-sign modules after stripping (INSTALL_MOD_STRIP removes embedded signatures)
  if [[ "$_RESIGN_AFTER_STRIP" == "true" ]] && [[ "$_STRIP" == "true" ]]; then
    if _resolve_signing_params; then
      msg2 "Re-signing kernel modules after strip..."
      find "${modulesdir}" -type f -name '*.ko' \
        -exec "${_sign_script}" "${_sign_hash}" "${_sign_key}" "${_sign_cert}" '{}' \;
    else
      warning "_RESIGN_AFTER_STRIP is enabled but signing is not available — skipping module re-signing."
    fi
  fi

  # install cleanup pacman hook and script
  sed -e "s|cleanup|${pkgbase}-cleanup|g" "${srcdir}"/90-cleanup.hook |
    install -Dm644 /dev/stdin "${pkgdir}/usr/share/libalpm/hooks/90-${pkgbase}.hook"
  install -Dm755 "${srcdir}"/cleanup "${pkgdir}/usr/share/libalpm/scripts/${pkgbase}-cleanup"

  # install customization file, for reference
  install -Dm644 "${srcdir}"/customization-full.cfg "${pkgdir}/usr/share/doc/${pkgbase}/customization.cfg"

  # ntsync
  if [ -e "${srcdir}/ntsync.conf" ]; then
    # workaround for missing header on <6.14 with ntsync
    if [ $_basever -lt 614 ]; then
      if [ -e "${_kernel_work_folder_abs}/include/uapi/linux/ntsync.h" ] && [ ! -e "/usr/include/linux/ntsync.h" ]; then
        msg2 "Workaround missing ntsync header"
        install -Dm644 "${_kernel_work_folder_abs}"/include/uapi/linux/ntsync.h "${pkgdir}/usr/include/linux/ntsync.h"
      fi
    fi
    # load ntsync module at boot
    msg2 "Set the ntsync module to be loaded at boot through /etc/modules-load.d"
    install -Dm644 "${srcdir}"/ntsync.conf "${pkgdir}/etc/modules-load.d/ntsync-${pkgbase}.conf"
  fi

  # install udev rule for ntsync if needed (<6.14)
  if [ -e "${srcdir}/ntsync.rules" ]; then
    msg2 "Installing udev rule for ntsync"
    install -Dm644 "${srcdir}"/ntsync.rules "${pkgdir}/etc/udev/rules.d/ntsync.rules"
  fi

  _module_drv_install
}

hackheaders() {
  source "$_where"/BIG_UGLY_FROGMINER

  pkgdesc="Headers and scripts for building modules for the $pkgdesc kernel - https://github.com/Frogging-Family/linux-tkg"
  provides=("linux-headers=${pkgver}" "${pkgbase}-headers=${pkgver}")
  depends=(
    binutils
    glibc
    libelf
    libgcc
    openssl
    pahole
    xxhash
    zlib
    zstd
  )

  cd "$_kernel_work_folder_abs"

  local builddir="${pkgdir}/usr/lib/modules/$(<version)/build"

  msg2 "Installing build files..."
  install -Dt "$builddir" -m644 .config Makefile Module.symvers System.map \
    localversion.* version vmlinux
  install -Dt "$builddir/kernel" -m644 kernel/Makefile
  install -Dt "$builddir/arch/x86" -m644 arch/x86/Makefile
  cp -t "$builddir" -a scripts

  # Install kernel signing keys for later out-of-tree module signing
  if [[ "$_install_signing_keys" == "true" ]] && [[ -f "certs/signing_key.pem" ]]; then
    msg2 "Installing module signing keys..."
    install -Dt "$builddir/certs" -m 400 certs/signing_key.pem certs/signing_key.x509
  fi

  # add objtool for external module building and enabled VALIDATION_STACK option
  install -Dt "$builddir/tools/objtool" tools/objtool/objtool

  # add xfs and shmem for aufs building
  mkdir -p "$builddir"/{fs/xfs,mm}

  # add resolve_btfids on 5.16+
  if [[ $_kver -ge 516 ]]; then
    install -Dt "$builddir"/tools/bpf/resolve_btfids tools/bpf/resolve_btfids/resolve_btfids || ( warning "$builddir/tools/bpf/resolve_btfids was not found. This is undesirable and might break dkms modules !!! Please review your config changes and consider using the provided defconfig and tweaks without further modification." && read -rp "Press enter to continue anyway" )
  fi

  msg2 "Installing headers..."
  cp -t "$builddir" -a include
  cp -t "$builddir/arch/x86" -a arch/x86/include
  install -Dt "$builddir/arch/x86/kernel" -m644 arch/x86/kernel/asm-offsets.s

  install -Dt "$builddir/drivers/md" -m644 drivers/md/*.h
  install -Dt "$builddir/net/mac80211" -m644 net/mac80211/*.h

  # http://bugs.archlinux.org/task/13146
  install -Dt "$builddir/drivers/media/i2c" -m644 drivers/media/i2c/msp3400-driver.h

  # http://bugs.archlinux.org/task/20402
  install -Dt "$builddir/drivers/media/usb/dvb-usb" -m644 drivers/media/usb/dvb-usb/*.h
  install -Dt "$builddir/drivers/media/dvb-frontends" -m644 drivers/media/dvb-frontends/*.h
  install -Dt "$builddir/drivers/media/tuners" -m644 drivers/media/tuners/*.h

  msg2 "Installing KConfig files..."
  find . -name 'Kconfig*' -exec install -Dm644 {} "$builddir/{}" \;

  msg2 "Removing unneeded architectures..."
  local arch
  for arch in "$builddir"/arch/*/; do
    [[ $arch = */x86/ ]] && continue
    echo "Removing $(basename "$arch")"
    rm -r "$arch"
  done

  msg2 "Removing documentation..."
  rm -r "$builddir/Documentation"

  msg2 "Removing broken symlinks..."
  find -L "$builddir" -type l -printf 'Removing %P\n' -delete

  msg2 "Removing loose objects..."
  find "$builddir" -type f -name '*.o' -printf 'Removing %P\n' -delete

  msg2 "Stripping build tools..."
  local file
  while read -rd '' file; do
    case "$(file -Sib "$file")" in
      application/x-sharedlib\;*)      # Libraries (.so)
        strip -v $STRIP_SHARED "$file" ;;
      application/x-archive\;*)        # Libraries (.a)
        strip -v $STRIP_STATIC "$file" ;;
      application/x-executable\;*)     # Binaries
        strip -v $STRIP_BINARIES "$file" ;;
      application/x-pie-executable\;*) # Relocatable binaries
        strip -v $STRIP_SHARED "$file" ;;
    esac
  done < <(find "$builddir" -type f -perm -u+x ! -name vmlinux -print0)

  msg2 "Adding symlink..."
  mkdir -p "$pkgdir/usr/src"
  ln -sr "$builddir" "$pkgdir/usr/src/$pkgbase"

  if [ "$_STRIP" = "true" ]; then
    echo "Stripping vmlinux..."
    strip -v $STRIP_STATIC "$builddir/vmlinux"
  fi

  # Skip srcdir cleanup if nvidia-open package still needs it (runs after headers)
  if [ "$_NUKR" = "true" ] && { [ "$_nvidia_open" = "false" ] || [ -z "$_nvidia_open" ]; }; then
    rm -rf "$srcdir" # Nuke the entire src folder so it'll get regenerated clean on next build
  fi
}

hacknvidia_open() {
  source "$_where"/BIG_UGLY_FROGMINER

  # Derive _nv_open_pkg here in case it wasn't set at PKGBUILD load time
  if [ -z "$_nv_open_pkg" ] && [ "$_nvidia_open" != "false" ] && [ -n "$_nvidia_open" ]; then
    if [ "$_nvidia_open" = "vulkan" ]; then
      _nv_open_pkg="open-gpu-kernel-modules-${_nvidia_open_version}"
    else
      _nv_open_pkg="NVIDIA-kernel-module-source-${_nvidia_open_version}"
    fi
  fi

  pkgdesc="NVIDIA open modules driver $_nvidia_open_version for the $pkgdesc kernel"
  depends=("${pkgbase}=${pkgver}" "libglvnd" "nvidia-utils-tkg>=${_nvidia_open_version}")
  provides=("NVIDIA-MODULE")
  conflicts=("${pkgbase}-nvidia" "NVIDIA-MODULE")
  license=('MIT AND GPL-2.0-only')

  local _nv_open_src="${srcdir}/${_nv_open_pkg}"

  cd "$_kernel_work_folder_abs"
  local _kernver="$(<version)"
  local modulesdir="$pkgdir/usr/lib/modules/$_kernver/extramodules"

  install -dm755 "${modulesdir}"
  install -m644 "${_nv_open_src}"/kernel-open/*.ko "${modulesdir}"
  install -Dt "$pkgdir/usr/share/licenses/${pkgname}" -m644 "${_nv_open_src}/COPYING"

  # Strip modules
  local strip_bin="strip"
  [ "$_compiler_name" = "-llvm" ] && strip_bin="llvm-strip"
  find "${modulesdir}" -type f -name '*.ko' -exec "${strip_bin}" --strip-debug '{}' \;

  # Sign modules
  if [[ "$_nvidia_open_sign" == "true" ]]; then
    if _resolve_signing_params; then
      msg2 "Signing NVIDIA open kernel modules..."
      find "${modulesdir}" -type f -name '*.ko' \
        -exec "${_sign_script}" "${_sign_hash}" "${_sign_key}" "${_sign_cert}" '{}' \;
    else
      warning "_nvidia_open_sign is enabled but signing is not available — skipping module signing."
    fi
  fi

  # Compress modules
  find "${pkgdir}" -name '*.ko' -exec zstd --rm -19 -T0 {} +

  # nvidia-open is the last package
  if [ "$_NUKR" = "true" ]; then
    rm -rf "$srcdir" # Nuke the entire src folder so it'll get regenerated clean on next build
  fi
}

source /dev/stdin <<EOF
package_${pkgbase}() {
hackbase
}

package_${pkgbase}-headers() {
hackheaders
}
$( [ "$_nvidia_open" != "false" ] && [ -n "$_nvidia_open" ] && printf 'package_%s-nvidia-open() {\nhacknvidia_open\n}' "${pkgbase}" )
EOF
