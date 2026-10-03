# Linux-tkg

My small personal Frankenstein-style fork for testing patches and configs.

This fork tracks [upstream](https://github.com/Frogging-Family/linux-tkg) closely and adds some spice on top.

## Extra knobs

All user-facing staging options are documented in [`customization.cfg`](customization.cfg#L366) under `STAGING OPTIONS`.

- <sub>Extra patchsets for memory, storage, networking and gaming, including [ADIOS](https://github.com/firelzrd/adios), [BBRv3](https://github.com/google/bbr/tree/v3) and Steam Deck support.</sub>
- <sub>Optional kernel modules and drivers:</sub>
  - <sub>Full [nvidia-all](https://github.com/Frogging-Family/nvidia-all) driver stack for Arch.*</sub>
  - <sub>Mainboard monitoring drivers: [it87](https://github.com/frankcrawford/it87) and [nct6687](https://github.com/Fred78290/nct6687d).</sub>
- <sub>Includes [Infinity](https://github.com/galpt/infinity-scheduler) as an optional CPU/GPU scheduler.</sub>

\* For a clean setup with NVIDIA, using [tkginstaller](https://github.com/damachine/tkginstaller) is recommended.

Profile-guided optimization, step by step: [AutoFDO, Propeller, and BOLT](optimization/readme.md).

The goal is to contribute stable and maintainable changes [upstream](https://github.com/Frogging-Family/linux-tkg) whenever possible.

Please do not report bugs from this fork to [upstream](https://github.com/Frogging-Family/linux-tkg).
