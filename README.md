# SAKURA-X-SHELL

This repository provides a shell template for SAKURA-X board.
Vivado 2023.2 was used to verify the design.

## Overview

SAKURA-X is composed of two FPGAs, Spartan-6 and Kintex-7.
Once the Spartan-6 FPGA is configured with the provided design,
you don't need to reconfigure it.
The Spartan-6 FPGA is responsible for bridging the Kinex-7 FPGA and the host PC.

The Kintex-7 FPGA is designed to implement your cryptographic module.
The shell template provides an AXI4 interface to connect your IP.
So, you can easily implement your IP, which has an AXI4 interface, and communicate with the host PC via USB.
Thanks to the AXI4 interface, a multi-clock design is also available.
The template optionally includes a Memory Interface Generator (MIG) IP to use DDR memory.

<img src="doc/images/overview.png" width="400"  style="display: block; margin: auto;" />

## Project for Spartan-6
[sakura-x-shell-ctrl](./sakura-x-shell-ctrl) includes ISE project for Spartan-6 FPGA.
In addition, pre-built bitstream file and MCS file are included in that directory.
The pre-built design is clocked at 20 MHz.
Please see [Configuration with iMPACT](./doc/config_with_impact.md) to configure the Spartan-6 FPGA.

## Create a template project for Kintex-7

First, clone this repository.
```bash
git clone --recursive https://github.com/hal-lab-u-tokyo/sakura-x-shell.git
cd sakura-x-shell
```

The following command will launch Vivado and create a project
```bash
vivado -source <path to this repo>/vivado/init-shell-project.tcl
```
For more details, see [doc/create_project.md](doc/create_project.md).

## Communication with SAKURA-X

We also provide driver software to communicate with SAKURA-X via USB.
It is included in our [ChipWhisperer Plugin](https://github.com/hal-lab-u-tokyo/chipwhisperer-enhanced-plugins).
Thus, it is compatible with [ChipWhisperer](https://github.com/newaetech/chipwhisperer), which is a popular open-source tool for side-channel analysis.

To communicate with your cryptographic module on SAKURA-X,
you have only to implement a Python class derived from a base class provided in the plugin.
The base class already implements common functions to communicate with SAKURA-X controller part.
For more details, see [here](https://github.com/hal-lab-u-tokyo/chipwhisperer-enhanced-plugins/blob/master/docs/hardware.md)

## Block design examples to integrate cryptographic modules

This repository contains cryptographic module examples as a submodule.
Detailed information about each example is available in the [submodule repository](https://github.com/hal-lab-u-tokyo/sca_design_repo).

`examples` directory includes scripts to create block designs with the cryptographic modules.

### RTL implementation of AES 128-bit encryption

After creating a project with the template, as described above, you can create a block design by running the following command in the Vivado Tcl console.
```tcl
source <path to this repo>/examples/aes128_aist_rtl/create_bd.tcl
```

To run the encryption with the design, please use `SakuraXShellExampleAES128BitRTL` class in the ChipWhisperer Plugin.

Another RTL implementation of AES 128-bit encryption is available in `examples/aes128_googlevault_rtl`.
The same class `SakuraXShellExampleAES128BitRTL` can be used to run the encryption with the design but don't forget to set `implementation="google"` argument when `con` method is called.

### HLS implementation of AES 128-bit encryption

First, you need to create an IP package from the HLS source code.
In `examples/aes128_hls` directory, a script to create an IP package is available.

```bash
cd examples/aes128_hls
sh create_ip.sh
```
It will create an IP package in `examples/aes128_hls/hls_sakura-x_aes_enc`.

After creating a project with the template, as described above, you can create a block design by running the following command in the Vivado Tcl console.
```tcl
source <path to this repo>/examples/aes128_hls/create_bd.tcl
```

To run the encryption with the design, please use `SakuraXShellExampleAES128BitHLS` class in the ChipWhisperer Plugin.

### VexRiscv on SAKURA-X
32bit RISC-V core, VexRiscv, is also available on SAKURA-X.

See [VexRiscv_SAKURA-X repo](https://github.com/hal-lab-u-tokyo/VexRiscv_SakuraX) for more details.

## License

This repository is licensed under MIT License, see [LICENSE](LICENSE) for more information.


## Similar projects
* [CW305 shell](https://github.com/hal-lab-u-tokyo/cw305-shell/) - A shell template for NewAE CW305 FPGA
