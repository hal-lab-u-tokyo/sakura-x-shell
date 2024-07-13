# SAKURA-X-SHELL

This repository provides a shell template for SAKURA-X board.
Using the template, you can easily connect your IP, which has AXI4 interface, using Vivado block design.
Vivado 2023.2 was used to verify the design.

## Create template project

First, clone this repository.
```bash
git clone https://github.com/hal-lab-u-tokyo/sakura-x-shell.git
```

Run the following command to launch Vivado and create a project
```bash
vivado -source vivado/init-shell-project.tcl
```
For more details, see [doc/create_project.md](doc/create_project.md).

## Design examples
To be added.

## License

This repository is licensed under MIT License, see [LICENSE](LICENSE) for more information.
