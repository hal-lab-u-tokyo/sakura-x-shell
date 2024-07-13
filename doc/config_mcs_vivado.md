SAKURA-X board has 28f128p30t-bpi-x16 flash memory for Kintex-7.
The flash memory can be used to store the bitstream file and configure the FPGA at boot time.
Using hardware manager in Vivado, the bitstream file can be programmed into the flash memory.

If you use ISE and Impact instead of Vivado, please refer to [this document](./config_spartan6.md).

## Create MCS file
This section describes how to create an MCS file from a bitstream file using Vivado.
If you have already created an MCS file or use pre-built example files, you can skip this section.

1. Open Vivado project

2. Select "Generate Memory Configuration File" from the "Tools" menu

<img src="./images/make_mcs_vivado.png" width="400"  style="display: block; margin: auto;" />

3. Select "MCS" as format type and "28f128p30t-bpi-x16" as Memory Part.
Then, set your preferred output filename.

4. Select "BPIx16" as interface type and check "Load bitstream files".

5. Select your bitstream file at the first row and set the address to 0x00000000 and direction to "up".

6. Click "OK" to generate the MCS file.

<img src="./images/make_mcs_details_vivado.png" width="400"  style="display: block; margin: auto;" />

## Program Flash Memory

1. Open Hardware Manager

2. Connect to the FPGA board using JTAG

3. Right-click on the FPGA device "xc7k160t" and select "Add Configuration Memory Device"

<img src="./images/add_mem_device_hardware_manager.png" width="400"  style="display: block; margin: auto;" />


4. Select "28f128p30t-bpi-x16" as the memory part and click "OK"

<img src="./images/select_mem_devive_hardware_manager.png" width="400"  style="display: block; margin: auto;" />

If the dialog as below appears, click "OK".

<img src="./images/add_mem_device_dialog_hardware_manager.png" width="400"  style="display: block; margin: auto;" />

5. Select the generated MCS file and click "OK". "Erase", "Program", and "Verify" should be checked.
After that, if no error occurs, the flash memory successfully programmed.

<img src="./images/select_mcs_file_hardware_manager.png" width="400"  style="display: block; margin: auto;" />

