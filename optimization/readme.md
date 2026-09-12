# Build linux-tkg profile optimization with AutoFDO, Propeller, and BOLT

Accurate, representative profiles are required. Google reports gains of around 10% in microbenchmarks and 5% in larger real-world workloads.

## Requirements

- Kernel 6.13 or newer
- Clang/LLVM 19 or newer (`llvm-profgen` and `llvm-profdata`)
- `llvm-propeller` installed for Propeller
- `llvm-bolt` and `perf2bolt` installed for BOLT
- BOLT currently supports x86-64 kernels 7.1 and 7.2 in linux-tkg
- `perf` installed and working with the running kernel; AMD profiling requires `perf` built with `libpfm` support

## Notes

- Run the documented commands from the root of the linux-tkg source tree.
- The helper `generate-profile.sh` automatically records the appropriate perf event and saves the profile in `~/.config/frogminer`, creating the directory if needed.
- Keep all build inputs unchanged across kernel builds, including `_compileroptlevel`, `_processor_opt`, `_lto_mode`, `_cpusched`, the remaining configuration, sources, patches, and compiler version.
- Each profile option points to its profile; `_llvm_propeller_profile` is the prefix of the two files created in step 4, not a separate file.

References:

- [Linux kernel AutoFDO documentation](https://docs.kernel.org/dev-tools/autofdo.html)
- [Linux kernel Propeller documentation](https://docs.kernel.org/dev-tools/propeller.html)
- [LLVM BOLT guide for the Linux kernel](https://github.com/llvm/llvm-project/blob/main/bolt/docs/OptimizingLinux.md)

<br>

## 1. Build AutoFDO Pass 1

Set in `customization.cfg`:

```ini
_compiler="llvm"
_lto_mode="thin"
_llvm_autofdo="pass1"
```

Automatic: `_llvm_propeller="false"`, `_debugdisable="false"`, `_STRIP="false"`; ignores
`_llvm_autofdo_profile` and `_llvm_propeller_profile`

Build with the normal command for your distribution:

```bash
# Arch
makepkg -si

# Other supported distributions
./install.sh install
```

Boot the new kernel.

<br>

## 2. Create the AutoFDO profile

Run the helper as your normal user:

```bash
./optimization/generate-profile.sh autofdo
```

The default recording lasts 600 seconds. Pass a different duration in seconds:

```bash
./optimization/generate-profile.sh autofdo 1800
```

Keep the system under representative load for the complete recording.

For example, spend about 600 seconds each:

- Playing games
- Compiling or running benchmarks
- Using normal desktop, network, and file workloads

The `sleep` command only sets the duration; `perf` records system-wide activity.

Output:

```text
~/.config/frogminer/tkg.afdo
```

<br>

## 3. Build AutoFDO Pass 2 + Propeller Pass 1

For AutoFDO-only, set `_llvm_propeller="false"` and use this as the final build.

To build AutoFDO + Propeller, set in `customization.cfg`:

```ini
_llvm_autofdo="pass2"
_llvm_autofdo_profile="~/.config/frogminer/tkg.afdo"

_llvm_propeller="pass1"
```

Automatic: `_debugdisable="false"`, `_STRIP="false"`; ignores
`_llvm_propeller_profile`

Build with the normal command for your distribution:

```bash
# Arch
makepkg -si

# Other supported distributions
./install.sh install
```

Boot the new kernel.

<br>

## 4. Create the Propeller profiles

After booting the kernel built in step 3, run:

```bash
./optimization/generate-profile.sh propeller
```

The default recording lasts 600 seconds. To record for 1800 seconds:

```bash
./optimization/generate-profile.sh propeller 1800
```

Use the same representative workloads during the complete Propeller recording.

Output:

```text
~/.config/frogminer/tkg-propeller_cc_profile.txt
~/.config/frogminer/tkg-propeller_ld_profile.txt
```

The helper creates both files using the default prefix
`~/.config/frogminer/tkg-propeller`.

<br>

## 5. Build the final kernel

Set:

```ini
_llvm_autofdo="pass2"
_llvm_autofdo_profile="~/.config/frogminer/tkg.afdo"
_llvm_propeller="pass2"
_llvm_propeller_profile="~/.config/frogminer/tkg-propeller"

# optional; allowed again
_STRIP="true"
```

`pass2` means that the configured profiles must be used:

- If the AutoFDO profile is missing, both AutoFDO and Propeller are disabled.
- If only a Propeller profile is missing, AutoFDO remains enabled and Propeller
  is disabled.

Build and install the kernel once more. The final build must report both the
AutoFDO and Propeller profiles.

Build with the normal command for your distribution:

```bash
# Arch
makepkg -si

# Other supported distributions
./install.sh install
```

Boot the new AutoFDO + Propeller build kernel! 🚀

<br>

# Optional BOLT extension

BOLT optimizes the linked `vmlinux` after AutoFDO and Propeller. It needs
one profiling build and one final build.

## 6. Build BOLT Pass 1

Keep the final compiler profile settings from step 5 and add:

```ini
_llvm_bolt="pass1"
```

`_debugdisable="false"` and `_STRIP="false"` are forced automatically. Build,
install, and boot this kernel.

Do not rebuild or change its configuration before creating the BOLT profile.
The helper needs the exact unstripped `vmlinux` from this running kernel. The
default path is:

```text
/lib/modules/$(uname -r)/build/vmlinux
```

## 7. Create the BOLT profile

```bash
./optimization/generate-profile.sh bolt
```

The default recording lasts 600 seconds. For 1800 seconds at a lower sampling
frequency:

```bash
BOLT_FREQUENCY=1000 ./optimization/generate-profile.sh bolt 1800
```

Output:

```text
~/.config/frogminer/tkg.fdata
```

If the matching `vmlinux` is stored elsewhere, specify it explicitly:

```bash
VMLINUX=/path/to/pass1/vmlinux ./optimization/generate-profile.sh bolt
```

## 8. Build BOLT Pass 2

Keep every other build setting unchanged and change only:

```ini
_llvm_bolt="pass2"
_llvm_bolt_profile="~/.config/frogminer/tkg.fdata"
```

Build and install once more. The build must report the BOLT profile and
`BOLT vmlinux`. Boot the final kernel.
