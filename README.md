# Linux-tkg

### This fork tracks [upstream](https://github.com/Frogging-Family/linux-tkg) closely and adds some spice on top.

> [!NOTE]
> **New to linux-tkg?** Start with the [upstream project README](https://github.com/Frogging-Family/linux-tkg) to get familiar with the general concept, the available options and the build workflow. Come back here once you know the basics.

---

<br />

### Extra knobs in `customization.cfg`

All on top of what upstream already offers.

#### `_nvidia_open` — builds the open-source NVIDIA kernel modules alongside the kernel package

| Value | Description |
|---|---|
| `"false"` | Disable (default) |
| `"latest"` | Lastest NVIDIA driver branch |
| `"vulkan"` | Vulkan developer beta branch |
| `"legacy"` | Older NVIDIA LTS driver branch |

Examples:

```properties
_nvidia_open="vulkan"
```

The matching driver version and the list of supported kernels for this module are defined in `linux-tkg-config/prepare` at https://github.com/damachine/linux-tkg/blob/staging/linux-tkg-config/prepare#L114-L118.

<br />

#### `_module_drv` — build third-party out-of-tree (e.g. motherboard chipset) kernel modules alongside the kernel package

Examples:

```properties
_module_drv="nct6687 v4l2loopback"
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

> These options below were added for personal testing and are left in for anyone who might find it useful.

#### `_nvidia_open_sign` — sign NVIDIA open modules (experimental)

```properties
_nvidia_open_sign="false"
```

When set to `"true"`, all `nvidia*.ko` files in the NVIDIA open modules package are signed using the kernel's module signing key after building.

Useful in combination with `_RESIGN_AFTER_STRIP` to prevent unsigned-module taint messages. Requires `CONFIG_MODULE_SIG=y`. Has no effect when `_nvidia_open` is `"false"` or empty.


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
>
> A common alternative is to enroll your own MOK (Machine Owner Key) via `mokutil --import` and sign modules manually with it — that way the signing key never ends up in the kernel headers package at all. Another approach is building a UKI (Unified Kernel Image) with `ukify`, which embeds the kernel and initramfs into a single signed EFI binary, making per-module signing unnecessary entirely.

---

### Install (Arch & derivatives)

```shell
git clone https://github.com/damachine/linux-tkg.git
cd linux-tkg
makepkg -si
```

Has no effect when using `install.sh` on Debian, Ubuntu, Fedora, etc. maybe later ;)

---
