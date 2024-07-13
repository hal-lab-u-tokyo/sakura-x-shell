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

<img src="doc/images/overview.png" width="400" />

## Project for Spartan-6
[sakura-x-shell-ctrl](./sakura-x-shell-ctrl) includes ISE project for Spartan-6 FPGA.
In addition, pre-built bitstream file and MCS file are included in that directory.
The pre-built design is clocked at 50 MHz.
Please see [Configuration with iMPACT](./doc/config_with_impact.md) to configure the Spartan-6 FPGA.

## Create a template project for Kintex-7

First, clone this repository.
```bash
git clone https://github.com/hal-lab-u-tokyo/sakura-x-shell.git
cd sakura-x-shell
```

The following command will launch Vivado and create a project
```bash
vivado -source vivado/init-shell-project.tcl
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

## Design examples
### RTL implementation of AES 128-bit encryption
[ip_repo](./vivado/ip_repo) contains an IP core wrapping sasebo-giii AES core developed by AIST.

After creating a project with the template, as described above, you can create a block design by running the following command in the Vivado Tcl console.
```tcl
source <path to this repo>/examples/aes128_rtl/create_bd.tcl
```

### HLS implementation of AES 128-bit encryption

Corresponding HLS code is also available in [examples/aes128_hls](./examples/aes128_hls).

To create an IP core from the HLS code, go to the directory and run the following command:
```bash
vitis_hls -f create_ip.tcl
```
Then, the HLS project will be created in the `hls_sakura_aes_enc`.
The generated IP core depends on the target frequency.
The above tcl script sets the target frequency to 50MHz.


### VexRiscv on SAKURA-X


## License

This repository is licensed under MIT License, see [LICENSE](LICENSE) for more information.
