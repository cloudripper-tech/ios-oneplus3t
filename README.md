# ios-oneplus3t

**Porting Apple's iOS 16 XNU kernel to the OnePlus 3T (`oneplus3t`, Snapdragon 821 / MSM8996 Pro).**

This project adapts the Google Pixel 1 (`sailfish`) and Redmi Note 10 Pro (`sweet`) XNU porting framework ([dipa-studio/ios-sweet](https://github.com/dipa-studio/ios-sweet), [joranv1/ios-sailfish](https://github.com/joranv1/ios-sailfish)) to the **OnePlus 3T**. It integrates a custom bare-metal boot shim, MDP5 framebuffer geometry, PM8994 SPMI button mappings, Synaptics S3320 touch driver support, and a complete 16 GB case-sensitive HFS+ userland filesystem deployment onto internal UFS storage.

> Experimental bring-up. Security is switched off and it installs directly into the `userdata` partition, **erasing Android's user data**.

## Current Status

| Area | State |
| --- | --- |
| Boot Shim | Compiles and boots via `fastboot boot` on physical OnePlus 3T hardware with a live text console and 1080x1920 BGR framebuffer kickoff (`0x83400000`) |
| Hardware Topology | Matched memory topology (6 GB upper DDR bank at `0x100000000`), GICv3 (`0x9bc0000`, stride `0x40000`), UFS host (`0x624000`), and Kryo CPU cores |
| Input Drivers | PM8994 Volume Up/Down and Home buttons (`KEY_HOME`), plus Synaptics S3320 touchscreen (`0x075ba000`) |
| iOS Root Filesystem | 16 GB case-sensitive HFS+ userland image assembled from the official iPhone 8 iOS 16.7.16 IPSW and flashed via Android sparse format (`iOSRoot.simg`) to `userdata` (`rd=ufsroot0`) |

## Repository Layout

- `shim/`: Bare-metal ARM64 boot shim (`oneplus3t.c`, `console.c`, `pstore.c`, `loader.c`)
- `xnu/patches/`: Kernel patch series (including OP3T keys and touch `0184`)
- `tools/mkadt.py`: Apple Device Tree generator supporting `--oneplus3t`
- `tools/mkpayload.py`: Kernel and device tree payload packer
- `tools/mkiosroot.sh`: iOS HFS+ root filesystem builder

## Credits

- **Bhavinjain260** for OnePlus 3 XNU porting references (`ios-oneplus3`).
- **joranv1** and **dipa-studio** for the Sailfish/Sweet XNU port and driver infrastructure.
