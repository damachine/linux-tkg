# Linux-tkg

This fork tracks [upstream](https://github.com/Frogging-Family/linux-tkg) closely and adds some spice on top.

Please do not report bugs from this fork to upstream.

## Extra knoobs

| Feature | Config file | Main public options |
|---|---|---|
| Clang AutoFDO | [`linux-tkg-config/autofdo`](linux-tkg-config/autofdo) | `_autofdo`, `_autofdo_profile_path` |
| Clang Propeller | [`linux-tkg-config/propeller`](linux-tkg-config/propeller) | `_propeller`, `_propeller_profile_path` |
| Extra patches | [`linux-tkg-config/patches-staging`](linux-tkg-config/patches-staging) | `_glitched_staging`, `_misc_staging`, `_adios`, `_bbr3` |
| Docs package | [`linux-tkg-config/docs-pkg`](linux-tkg-config/docs-pkg) | `_docs_pkg` |
| Module signing | [`linux-tkg-config/module-signing`](linux-tkg-config/module-signing) | `_RESIGN_AFTER_STRIP`, `_install_signing_keys` |
| Third-party modules | [`linux-tkg-config/module-driver`](linux-tkg-config/module-driver) | `_module_pkg`, `_module_extpkg`, `_module_autoload`, `_module_options_*`, `_module_git_*`, `_module_sign` |
| NVIDIA open modules | [`linux-tkg-config/nvidia-open`](linux-tkg-config/nvidia-open) | `_nvidia_pkg`, `_nvidia_sign` |

Leave an option unset to keep the normal prompt/default behavior; set it in `customization.cfg` or in the external config file to make it deterministic.

## Install procedure

Use the regular workflow. Start with the upstream README if you are new to linux-tkg, then enable only the feature files/options you need in this fork.
