# Linux-tkg

> [!NOTE]
> **New to linux-tkg?** Start with the [upstream project README](https://github.com/Frogging-Family/linux-tkg) to get familiar with the general concept, the available options and the build workflow. Come back here once you know the basics.

---

## Install (Arch & derivatives)

```shell
git clone --branch staging https://github.com/damachine/linux-tkg.git
cd linux-tkg
# Optional: edit customization.cfg
makepkg -si
```

---

## This fork — what's different

> [!NOTE]
> This is a personal staging fork of [Frogging-Family/linux-tkg](https://github.com/Frogging-Family/linux-tkg).
> It tracks upstream closely and adds a small number of improvements on top.

### Additional options in `customization.cfg`

The following settings are available in this fork **in addition to** what the upstream `customization.cfg` already provides.

---

#### NVIDIA open modules — three driver branches

Upstream offers two choices for `_nvidia_open`; this fork adds a third:

| Value | Description |
|---|---|
| `"false"` | Disable (default) |
| `"latest"` | Lastest NVIDIA driver branch |
| `"vulkan"` | Vulkan developer beta branch |
| `"legacy"` | Older NVIDIA LTS driver branch |

```properties
_nvidia_open="vulkan"
```

The matching driver version is defined in `linux-tkg-config/prepare` as `_nvidia_open_vulkan_version`.

---

#### `_module_drv` — build third-party out-of-tree modules (Arch only)

```properties
_module_drv="nct6687d it87 v4l2loopback"
```

Builds selected out-of-tree kernel modules into the main kernel package at build time. Supported modules:

| Module | Chip / Controller | Description | Source |
|---|---|---|---|
| `nct6687d` | Nuvoton [NCT6687-R](https://www.nuvoton.com/products/pc-health-monitor-ics/nct6687-r/) (common on MSI & Gigabyte boards) | Hardware monitoring driver (fans, temps, voltages) | [Fred78290/nct6687d](https://github.com/Fred78290/nct6687d) |
| `it87` | ITE [IT8689E / IT8792E](https://www.ite.com.tw/en/product/category/Env_EC) / IT87xx series (common on ASUS & ASRock boards) | Hardware monitoring driver (fans, temps, voltages) | [frankcrawford/it87](https://github.com/frankcrawford/it87) |
| `v4l2loopback` | Virtual (no physical chip; kernel-level loopback) | Creates virtual video devices usable as webcam sources (e.g. OBS → Zoom) | [v4l2loopback/v4l2loopback](https://github.com/v4l2loopback/v4l2loopback) |

Has no effect when using `install.sh` on Debian, Ubuntu, Fedora, etc.

**Companion options** (all ignored when `_module_drv` is empty):

| Option | Description |
|---|---|
| `_module_drv_autoload` | Space-separated subset of modules to autoload at boot via `/usr/lib/modules-load.d/`. `v4l2loopback` is autoloaded by default for compatibility. |
| `_module_drv_sign` | `"false"` / empty = no signing (default), `"true"` = sign all active modules, or a space-separated subset to sign selectively. Requires `CONFIG_MODULE_SIG=y`. |
| `_module_drv_options_<name>` | Per-module modprobe options written to `/usr/lib/modprobe.d/`. Available for `nct6687d`, `it87`, and `v4l2loopback`. |
| `_module_drv_git_<name>` | Pin a specific git ref (branch, tag, or commit) for a module, or set a full URL (`https://…` / `git@…`) to clone from a different fork entirely. Leave empty to use the default upstream repository at its default branch. |

Examples:

```properties
# Enable two modules
_module_drv="nct6687d v4l2loopback"

# Autoload nct6687d at boot
_module_drv_autoload="nct6687d"

# Sign only nct6687d
_module_drv_sign="nct6687d"

# modprobe options for nct6687d (space-separated, produces a single "options" line)
_module_drv_options_nct6687d="fan_config=msi_alt1 msi_fan_brute_force=1"

# Pin nct6687d to a specific commit
_module_drv_git_nct6687d="abc1234"

# Or switch to a completely different fork URL
_module_drv_git_nct6687d="https://github.com/otherfork/nct6687d.git"
```

> **Note:** When a full URL is provided, the default branch of that fork is cloned.
> It is not possible to combine a custom URL with a specific ref in the same variable.

---

#### `_nvidia_open_sign` — sign NVIDIA open modules (experimental)

This option was added for personal testing and is left in for anyone who might find it useful.

```properties
_nvidia_open_sign="false"
```

When set to `"true"`, all `nvidia*.ko` files in the NVIDIA open modules package are signed using the kernel's module signing key after building.

Useful in combination with `_RESIGN_AFTER_STRIP` to prevent unsigned-module taint messages. Requires `CONFIG_MODULE_SIG=y`. Has no effect when `_nvidia_open` is `"false"` or empty.


#### `_install_signing_keys` — keep signing key in headers package (experimental)

This option was added for personal testing and is left in for anyone who might find it useful.

```properties
_install_signing_keys="false"
```

When set to `"true"`, the kernel module signing key (`signing_key.pem`) and certificate are installed into the headers package under `/usr/src/<pkgbase>/certs/` with permissions **400** (root-readable only), so you can sign out-of-tree modules manually afterwards (useful for Secure Boot workflows).

> [!WARNING]
> The key is stored unencrypted on disk. It is installed with permissions 400 (root-readable only), but anyone with root or physical access to the machine can extract it and sign arbitrary modules. If security is a concern, use full-disk encryption (e.g. LUKS) to protect the key against physical access.
>
> A common alternative is to enroll your own MOK (Machine Owner Key) via `mokutil --import` and sign modules manually with it — that way the signing key never ends up in the kernel headers package at all. Another approach is building a UKI (Unified Kernel Image) with `ukify`, which embeds the kernel and initramfs into a single signed EFI binary, making per-module signing unnecessary entirely.

---
