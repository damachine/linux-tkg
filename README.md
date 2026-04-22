# Linux-tkg

### This fork tracks [upstream](https://github.com/Frogging-Family/linux-tkg) closely and adds some spice on top.

> [!NOTE]
> **New to linux-tkg?** Start with the [upstream project README](https://github.com/Frogging-Family/linux-tkg) to get familiar with the general concept, the available options and the build workflow. Come back here once you know the basics.
> 
> Please do not report bugs to the upstream repository when using this fork.

---

<br />

### Extra knobs in `customization.cfg`

All on top of what upstream already offers — knobs live in [`customization.cfg`](https://github.com/damachine/linux-tkg/blob/staging/customization.cfg#L250-L360).

- [Linux-tkg](#linux-tkg)
    - [This fork tracks upstream closely and adds some spice on top.](#this-fork-tracks-upstream-closely-and-adds-some-spice-on-top)
    - [Extra knobs in `customization.cfg`](#extra-knobs-in-customizationcfg)
      - [`_nvidia_open` — builds the open-source NVIDIA kernel modules](#_nvidia_open--builds-the-open-source-nvidia-kernel-modules)
      - [`_module_drv` — build third-party out-of-tree (e.g. motherboard chipset)](#_module_drv--build-third-party-out-of-tree-eg-motherboard-chipset)
      - [`_aggressive_glitched_base` — aggressive VM/scheduler tuning defaults (experimental)](#_aggressive_glitched_base--aggressive-vmscheduler-tuning-defaults-experimental)
      - [`_aggressive_misc_adds` — aggressive misc additions (experimental)](#_aggressive_misc_adds--aggressive-misc-additions-experimental)
      - [`_aggressive_more_opts` — CPU/scheduler misc optimizations (experimental)](#_aggressive_more_opts--cpuscheduler-misc-optimizations-experimental)
      - [`_clang_polly` — Clang Polly loop optimizer support (experimental)](#_clang_polly--clang-polly-loop-optimizer-support-experimental)
      - [`_autofdo` / `_autofdo_profile_path` — Clang AutoFDO (experimental)](#_autofdo--_autofdo_profile_path--clang-autofdo-experimental)
      - [`_vanilla` — build a pure vanilla kernel without any modifications](#_vanilla--build-a-pure-vanilla-kernel-without-any-modifications)
      - [`_nvidia_open_sign` — sign NVIDIA open modules (experimental)](#_nvidia_open_sign--sign-nvidia-open-modules-experimental)
      - [`_RESIGN_AFTER_STRIP` — re-sign all modules after stripping (experimental)](#_resign_after_strip--re-sign-all-modules-after-stripping-experimental)
      - [`_module_drv_sign` — out-of-tree module signing (experimental)](#_module_drv_sign--out-of-tree-module-signing-experimental)
      - [`_install_signing_keys` — keep signing key in headers package (experimental)](#_install_signing_keys--keep-signing-key-in-headers-package-experimental)
    - [Install procedure](#install-procedure)

<br />


#### `_nvidia_open` — builds the open-source NVIDIA kernel modules

| Value | Description |
|---|---|
| `"false"` | Disable (skips prompt) |
| `"latest"` | Lastest NVIDIA driver branch |
| `"vulkan"` | Vulkan developer beta branch |
| `"legacy"` | Older NVIDIA LTS driver branch |

Examples:

```properties
_nvidia_open="vulkan"
```

Driver versions and supported kernels are pinned in [`linux-tkg-config/prepare`](https://github.com/damachine/linux-tkg/blob/staging/linux-tkg-config/prepare#L114-L118).

<br />

#### `_module_drv` — build third-party out-of-tree (e.g. motherboard chipset)

<br />

#### `_aggressive_glitched_base` — aggressive VM/scheduler tuning defaults (experimental)

```properties
_aggressive_glitched_base=""
```

Applies `0014-aggressive-glitched-base.patch`: workingset protection ratios, extended readahead, adjusted writeback and dirty thresholds, scheduler base slice and migration cost tuning, hugepage compaction tweaks — all gated behind `CONFIG_TKG`. Targets reduced stuttering on some workloads by keeping more file caches in memory. Requires `_glitched_base="true"`. Leave empty to be asked at build time.

<br />

#### `_aggressive_more_opts` — CPU/scheduler misc optimizations (experimental)

```properties
_aggressive_more_opts=""
```

Applies `0014-aggressive-more-opts.patch`: reduces `timer_slack_ns`, avoids `sched_move_task` lock contention, removes schedutil dependency, disables split-lock mitigation. Most noticeable on high core-count CPUs. Leave empty to be asked at build time.

#### User patches
Examples:

```properties
# enable modules
_module_drv="nct6687 v4l2loopback"

# disable all — skips prompt
_module_drv="false"
```

Builds selected out-of-tree kernel modules into the main kernel package at build time. Supported modules:

| Module | Chip / Controller | Description | Source |
|---|---|---|---|
| `nct6687` | Nuvoton NCT6687-R (common on MSI & Gigabyte boards) | Hardware monitoring driver (fans, temps, voltages) | [Fred78290/nct6687d](https://github.com/Fred78290/nct6687d) |
| `it87` | ITE IT8689E / IT8792E / IT87xx series (common on ASUS & ASRock boards) | Hardware monitoring driver (fans, temps, voltages) | [frankcrawford/it87](https://github.com/frankcrawford/it87) |
| `v4l2loopback` | Virtual (no physical chip; kernel-level loopback) | Creates virtual video devices usable as webcam sources (e.g. OBS → Zoom) | [v4l2loopback/v4l2loopback](https://github.com/v4l2loopback/v4l2loopback) |

**Companion options** (all ignored when `_module_drv` is empty):

| Option | Description |
|---|---|
| `_module_drv_autoload` | Space-separated subset of modules to autoload at boot via `/usr/lib/modules-load.d/`. `v4l2loopback` is autoloaded by default for compatibility. |
| `_module_drv_options_<name>` | Per-module modprobe options written to `/usr/lib/modprobe.d/`. Available for `nct6687`, `it87`, and `v4l2loopback`. |
| `_module_drv_git_<name>` | Pin a specific git ref (branch, tag, or commit) for a module, or set a full URL (`https://…` / `git@…`) to clone from a different fork entirely. Leave empty to use the default upstream repository at its default branch. |

Examples:

```properties
# Enable two modules
_module_drv="nct6687 v4l2loopback"

# Autoload nct6687 at boot
_module_drv_autoload="nct6687"

# modprobe options for nct6687 (space-separated, produces a single "options" line)
_module_drv_options_nct6687="fan_config=msi_alt1 msi_fan_brute_force=1"

# Pin nct6687 to a specific commit
_module_drv_git_nct6687="abc1234"

# Or switch to a completely different fork URL
_module_drv_git_nct6687="https://github.com/otherfork/nct6687d.git"
```

<br />

#### `_aggressive_glitched_base` — aggressive VM/scheduler tuning defaults (experimental)

```properties
_aggressive_glitched_base=""
```

Applies `0014-aggressive-glitched-base.patch`: workingset protection ratios, extended readahead, adjusted writeback and dirty thresholds, scheduler base slice and migration cost tuning, hugepage compaction tweaks — all gated behind `CONFIG_TKG`. Targets reduced stuttering on some workloads by keeping more file caches in memory. Requires `_glitched_base="true"`. Leave empty to be asked at build time.


#### `_aggressive_misc_adds` — aggressive misc additions (experimental)

```properties
_aggressive_misc_adds=""
```

Applies `0014-aggressive-misc-additions.patch`: may contain temporary fixes pending upstream or distro-specific compatibility fixes. Leave empty to be asked at build time.


#### `_aggressive_more_opts` — CPU/scheduler misc optimizations (experimental)

```properties
_aggressive_more_opts=""
```

Applies `0014-aggressive-more-opts.patch`: reduces `timer_slack_ns`, avoids `sched_move_task` lock contention, removes schedutil dependency, disables split-lock mitigation. Most noticeable on high core-count CPUs. Leave empty to be asked at build time.


#### `_clang_polly` — Clang Polly loop optimizer support (experimental)

```properties
_clang_polly=""
```

Applies `0014-clang-polly.patch` when available, enabling LLVM Polly for additional loop optimizations at compile time. Only meaningful when building with `_compiler="llvm"`. Leave empty to be asked at build time.

<br />

#### `_autofdo` / `_autofdo_profile_path` — Clang AutoFDO (experimental)

```properties
_autofdo=""
_autofdo_profile_path="~/.config/frogminer/kernel.afdo"
```

Two-pass PGO-like optimization using CPU hardware branch sampling. Requires `_compiler="llvm"`, kernel >= 6.11, and a CPU with LBR (Intel Haswell+) or (AMD Zen4+).

```properties
BUILD a profilable kernel
  _autofdo="true"
  _autofdo_profile_path="~/.config/frogminer/kernel.afdo"
  build & install kernel, then boot into it

PROFILE COLLECTION
  sudo echo 0 > /proc/sys/kernel/kptr_restrict
  sudo echo 0 > /proc/sys/kernel/perf_event_paranoid

  OR (via systemd):
  sudo sysctl -w kernel.kptr_restrict=0
  sudo sysctl -w kernel.perf_event_paranoid=0

  Intel (LBR):
    perf record -e BR_INST_RETIRED.NEAR_TAKEN:k -a -N -b -c 500009 -o \
      kernel.data -- <workload>
  AMD Zen4:
    perf record --pfm-events RETIRED_TAKEN_BRANCH_INSTRUCTIONS:k -a -N -b -c 500009 -o \
      kernel.data -- <workload>

CONVERT perf data (.afdo profile)
  mkdir -p ~/.config/frogminer
  llvm-profgen --kernel --binary=/usr/lib/modules/<kver>/build/vmlinux \
    --perfdata=kernel.data -o ~/.config/frogminer/kernel.afdo
  Merge multiple profiles (optional):
    llvm-profdata merge -o ~/.config/frogminer/kernel.afdo profile1.afdo profile2.afdo ...

SET _autofdo_profile_path to the .afdo file path, then rebuild the kernel.
```

<br />

#### `_vanilla` — build a pure vanilla kernel without any modifications

| Value | Description |
|---|---|
| `"false"` | Disable — normal TKG build (default) |
| `"true"` | Enable — build a stock kernel without any TKG patches or modifications |

Examples:

```properties
_vanilla="true"
```

When enabled, all TKG-specific patches, config modifications and kernel config fragments (`.myfrag`) are skipped. The CPU scheduler is set to the kernel default without prompting, the compiler is forced to `gcc`, and the kernel is named `-vanilla`.

<br />
<br />

<a name="signing--module-extras"></a>

> These options below were added for personal testing and are left in for anyone who might find it useful.

#### `_nvidia_open_sign` — sign NVIDIA open modules (experimental)

```properties
_nvidia_open_sign="false"
```

When set to `"true"`, all `nvidia*.ko` files in the NVIDIA open modules package are signed using the kernel's module signing key after building.

Useful in combination with `_RESIGN_AFTER_STRIP` to prevent unsigned-module taint messages. Requires `CONFIG_MODULE_SIG=y`. Has no effect when `_nvidia_open` is `"false"` or empty.


#### `_RESIGN_AFTER_STRIP` — re-sign all modules after stripping (experimental)

```properties
_RESIGN_AFTER_STRIP="false"
```

When set to `"true"`, all `.ko` files are re-signed with the kernel's module signing key after stripping. Prevents "module verification failed" taint messages caused by `INSTALL_MOD_STRIP=1` removing embedded signatures. Requires `CONFIG_MODULE_SIG=y`. Has no effect when `_STRIP` is not `"true"`.


#### `_module_drv_sign` — out-of-tree module signing (experimental)

```properties
_module_drv_sign="false"
```

When set to `"true"`, all active out-of-tree modules are signed using the kernel's module signing key after building. Alternatively, pass a space-separated subset of module names to sign only those selectively. Requires `CONFIG_MODULE_SIG=y`. Has no effect when `_module_drv` is empty.


#### `_install_signing_keys` — keep signing key in headers package (experimental)

```properties
_install_signing_keys="false"
```

When set to `"true"`, the kernel module signing key and certificate are installed into the linux-headers package (useful for Secure Boot workflows or to prevent unsigned-module taint messages). Requires `CONFIG_MODULE_SIG=y`. Has no effect when is `"false"` or empty.

> [!WARNING]
> The key is stored unencrypted on disk. It is installed with permissions 400 (root-readable only), but anyone with root or physical access to the machine can extract it and sign arbitrary modules. If security is a concern, use full-disk encryption (e.g. LUKS) to protect the key against physical access.

---

<br />

### Install procedure

> [!TIP]
> **Recommended:** Use [tkginstaller](https://github.com/damachine/tkginstaller) for an interactive guided build experience with fzf menus, automatic dependency handling, and config management.
> ```shell
> # install tkginstaller (AUR)
> yay -S tkginstaller-git
> 
> # Use fzf-finder TUI mode, simply run
> tkginstaller
> # Use direct command with package name, for example
> tkginstaller linux          # or shortcut l
> tkginstaller linux-nvidia   # or shortcut ln
> ```

(Arch & derivatives)

```shell
git clone https://github.com/damachine/linux-tkg.git
cd linux-tkg
makepkg -si
```

(Generic / Gentoo)

```shell
git clone https://github.com/damachine/linux-tkg.git
cd linux-tkg
./install.sh install
```

> `_module_drv` and its companion options should also work on **Generic** and **Gentoo**. Untested, use at your own risk.
>
> `install.sh` has no effect when using on Debian, Ubuntu, Fedora.

---
