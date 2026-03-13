# Linux-tkg

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

This is a personal staging fork of [Frogging-Family/linux-tkg](https://github.com/Frogging-Family/linux-tkg).
It tracks upstream closely and adds a small number of improvements on top.

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

| Module | Description |
|---|---|
| `nct6687d` | Nuvoton NCT6687-R hardware monitoring driver |
| `it87` | ITE IT87xx hardware monitoring driver |
| `v4l2loopback` | Virtual video loopback device driver |

Has no effect when using `install.sh` on Debian, Ubuntu, Fedora, etc.

**Companion options** (all ignored when `_module_drv` is empty):

| Option | Description |
|---|---|
| `_module_drv_autoload` | Space-separated subset of modules to autoload at boot via `/usr/lib/modules-load.d/`. `v4l2loopback` is autoloaded by default for compatibility. |
| `_module_drv_sign` | `"false"` / empty = no signing (default), `"true"` = sign all active modules, or a space-separated subset to sign selectively. Requires `CONFIG_MODULE_SIG=y`. |
| `_module_drv_options_<name>` | Per-module modprobe options written to `/usr/lib/modprobe.d/`. Available for `nct6687d`, `it87`, and `v4l2loopback`. |
| `_module_drv_git_<name>` | Pin a specific git ref (branch, tag, or commit) for a module. Leave empty to use the remote default branch. |

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

# Pin it87 to a specific branch
_module_drv_git_it87="master"
```

---

#### `_nvidia_open_sign` — sign NVIDIA open modules (experimental)

```properties
_nvidia_open_sign="false"
```

When set to `"true"`, all `nvidia*.ko` files in the NVIDIA open modules package are signed using the kernel's module signing key after building.

Useful in combination with `_RESIGN_AFTER_STRIP` to prevent unsigned-module taint messages. Requires `CONFIG_MODULE_SIG=y`. Has no effect when `_nvidia_open` is `"false"` or empty.

---

#### `_module_drv` — build third-party out-of-tree modules (Arch only)

```properties
_module_drv="nct6687d it87 v4l2loopback"
```

Builds selected out-of-tree kernel modules into the main kernel package at build time. Supported modules:

| Module | Description |
|---|---|
| `nct6687d` | Nuvoton NCT6687-R hardware monitoring driver |
| `

#### `_install_signing_keys` — keep signing key in headers package (experimental)

```properties
_install_signing_keys="false"
```

When set to `"true"`, the kernel module signing key (`signing_key.pem`) and certificate are installed into the headers package under `/usr/src/<pkgbase>/certs/` with permissions **400** (root-readable only), so you can sign out-of-tree modules manually afterwards (useful for Secure Boot workflows).

> **Security note:** The key is stored unencrypted on disk. It is installed with permissions 400 (root-readable only), but anyone with root or physical access to the machine can extract it and sign arbitrary modules. If security is a concern, use full-disk encryption (e.g. LUKS) to protect the key against physical access.

---
