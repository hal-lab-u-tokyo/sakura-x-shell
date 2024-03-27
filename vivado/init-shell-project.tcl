#
#    Copyright (C) 2024 The University of Tokyo
#
#    File:          /vivado/init-shell-project.tcl
#    Project:       sakura-x-shell
#    Author:        Takuya Kojima in The University of Tokyo (tkojima@hal.ipc.i.u-tokyo.ac.jp)
#    Created Date:  27-03-2024 20:56:01
#    Last Modified: 27-03-2024 20:56:01
#


# default settings
variable design_name
# your preferences
set project_name "proj_shell"
set project_dir "[file normalize "./$project_name"]"
set design_name "main"
set enable_mig 0

set script_file [file tail [info script]]

# Help information for this script
proc print_help {} {
	variable script_file
	puts "\nDescription:"
	puts "This script creates a template Vivado project for SAKURA-X Board."
	puts "This offers two types of project creation: one with MIG and one without MIG."
	puts "Syntax:"
	puts "$script_file"
	puts "$script_file -tclargs \[--project-dir <path>\]"
	puts "$script_file -tclargs \[--project-name <name>\]"
	puts "$script_file -tclargs \[--with-mig>\]"
	puts "$script_file -tclargs \[--help\]\n"
	puts "Usage:"
	puts "Name                   Description"
	puts "-------------------------------------------------------------------------"
	puts "\[--project-dir <path>\] Specify the directory where the project will be"
	puts "                         created. Default is the current directory."
	puts "\[--project-name <name>\] Create project with the specified name. Default"
	puts "                          name is \"proj_shell\"."
	puts "\[--with-mig\]           Create project with MIG. Default is without MIG."
	puts "\[--help\]               Print help information for this script"
	puts "-------------------------------------------------------------------------\n"
	exit 0
}

# arg parser
if { $::argc > 0 } {
	for {set i 0} {$i < $::argc} {incr i} {
		set option [string trim [lindex $::argv $i]]
		switch -regexp -- $option {
			"--project-dir"  { incr i; set project_dir [lindex $::argv $i] }
			"--project-name" { incr i; set project_name [lindex $::argv $i] }
		"--with-mig"	   { set enable_mig 1 }
			"--help"         { print_help }
			default {
				if { [regexp {^-} $option] } {
					puts "ERROR: Unknown option '$option' specified, please type '$script_file -tclargs --help' for usage info.\n"
					return 1
				}
			}
		}
	}
}


# IP repo path
set scriptPath [file normalize [info script]]
set scriptDir [file dirname $scriptPath]
set ip_repo_loc [file normalize [file join $scriptDir "ip_repo"]]

# create project
create_project $project_name $project_dir -part xc7k160tfbg676-1
set proj_dir [get_property directory [current_project]]

# source file set
set src_set [current_fileset -quiet]

# add IP repo
set_property "ip_repo_paths" "[file normalize $ip_repo_loc/controler_AXI_1_0]" $src_set
update_ip_catalog -rebuild

# constraint file set
set constr_set [current_fileset -quiet -constrset]

# add a constraint file
import_files -fileset $constr_set [file normalize [file join $scriptDir "sakura-x-k7.xdc"]]

# create design
create_bd_design $design_name
common::send_gid_msg -ssname BD::TCL -id 2004 -severity "INFO" "Making design <$design_name> as current_bd_design."
	 current_bd_design $design_name

# check IP
set bCheckIPsPassed 1
set list_check_ips "\ 
xilinx.com:ip:clk_wiz:6.0\
xilinx.com:ip:xlconstant:1.1\
xilinx.com:ip:axi_gpio:2.0\
tkojima.me:user:controler_AXI:1.0\
xilinx.com:ip:proc_sys_reset:5.0\
xilinx.com:ip:mig_7series:4.2\
xilinx.com:ip:xlslice:1.0\
"
set list_ips_missing ""
common::send_gid_msg -ssname BD::TCL -id 2011 -severity "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

foreach ip_vlnv $list_check_ips {
	set ip_obj [get_ipdefs -all $ip_vlnv]
	if { $ip_obj eq "" } {
		lappend list_ips_missing $ip_vlnv
	}
}

if { $list_ips_missing ne "" } {
	catch {common::send_gid_msg -ssname BD::TCL -id 2012 -severity "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
	set bCheckIPsPassed 0
}
if { $bCheckIPsPassed != 1 } {
	common::send_gid_msg -ssname BD::TCL -id 2023 -severity "WARNING" "Will not continue with creation of design due to the error(s) above."
	return 3
}

if { $enable_mig == 1 } {
	source [file normalize [file join $scriptDir "create_mig.tcl"]]
	import_files -fileset $constr_set [file normalize [file join $scriptDir "mig_clock.xdc"]]
}

proc create_root_design { parentCell enable_mig } {

	variable script_folder
	variable design_name

	if { $parentCell eq "" } {
		 set parentCell [get_bd_cells /]
	}

	# Get object for parentCell
	set parentObj [get_bd_cells $parentCell]
	if { $parentObj == "" } {
		 catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
		 return
	}

	# Make sure parentObj is hier blk
	set parentType [get_property TYPE $parentObj]
	if { $parentType ne "hier" } {
		 catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
		 return
	}

	# Save current instance; Restore later
	set oldCurInst [current_bd_instance .]

	# Set parent object as current
	current_bd_instance $parentObj


	# Create interface ports
	set i_osc [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 i_osc ]
	set_property -dict [ list \
	 CONFIG.FREQ_HZ {200000000} \
	 ] $i_osc


	# Create ports
	set o_read_data [ create_bd_port -dir O -from 31 -to 0 o_read_data ]
	set i_bus_reset_n [ create_bd_port -dir I -type rst i_bus_reset_n ]
	set bus_clk [ create_bd_port -dir I -type clk -freq_hz 50000000 bus_clk ]
	set o_clk_osc_inh_n [ create_bd_port -dir O -from 0 -to 0 o_clk_osc_inh_n ]
	set i_common [ create_bd_port -dir I -from 31 -to 0 -type data i_common ]
	set i_addr_valid [ create_bd_port -dir I i_addr_valid ]
	set i_write_enable [ create_bd_port -dir I i_write_enable ]
	set i_read_data_ready [ create_bd_port -dir I i_read_data_ready ]
	set o_addr_ready [ create_bd_port -dir O o_addr_ready ]
	set o_write_data_ready [ create_bd_port -dir O o_write_data_ready ]
	set o_read_data_valid [ create_bd_port -dir O o_read_data_valid ]
	set i_write_data_valid [ create_bd_port -dir I i_write_data_valid ]
	set o_led [ create_bd_port -dir O -from 9 -to 0 o_led ]

	# Create instance: pll, and set properties
	set pll [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 pll ]
	set pll_prop_base [list \
		CONFIG.CLKIN1_JITTER_PS {50.0} \
		CONFIG.CLKOUT1_JITTER {112.316} \
		CONFIG.CLKOUT1_PHASE_ERROR {89.971} \
		CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {100} \
		CONFIG.MMCM_CLKFBOUT_MULT_F {5.000} \
		CONFIG.MMCM_CLKIN1_PERIOD {5.000} \
		CONFIG.MMCM_CLKIN2_PERIOD {10.0} \
		CONFIG.MMCM_CLKOUT0_DIVIDE_F {10.000} \
		CONFIG.PRIM_IN_FREQ {200} \
		CONFIG.PRIM_SOURCE {Differential_clock_capable_pin} \
		CONFIG.RESET_PORT {resetn} \
		CONFIG.RESET_TYPE {ACTIVE_LOW} \
		CONFIG.USE_LOCKED {false} \
	]
	set mig_clock_prop [list CONFIG.CLKOUT2_JITTER {98.146} \
		CONFIG.CLKOUT2_PHASE_ERROR {89.971} \
		CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {200} \
		CONFIG.CLKOUT2_USED {true} \
		CONFIG.NUM_OUT_CLKS {2} \
	]
	if { $enable_mig != 1 } {
		set pll_prop [concat $pll_prop_base]
	} else {
		set pll_prop [concat $pll_prop_base $mig_clock_prop]
	}
	set_property -dict $pll_prop $pll

	# Create instance: xlconstant_0, and set properties
	set xlconstant_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0 ]

	# Create instance: axi_led, and set properties
	set axi_led [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_led ]
	set_property -dict [list \
		CONFIG.C_ALL_OUTPUTS {1} \
		CONFIG.C_DOUT_DEFAULT {0xFFFFFFFF} \
		CONFIG.C_GPIO_WIDTH {32} \
	] $axi_led


	# Create instance: controler_AXI_0, and set properties
	set controler_AXI_0 [ create_bd_cell -type ip -vlnv tkojima.me:user:controler_AXI:1.0 controler_AXI_0 ]

	# Create instance: controler_AXI_0_axi_periph, and set properties
	set controler_AXI_0_axi_periph [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 controler_AXI_0_axi_periph ]
	if { $enable_mig != 1 } {
	set_property CONFIG.NUM_MI {1} $controler_AXI_0_axi_periph
	} else {
	set_property CONFIG.NUM_MI {2} $controler_AXI_0_axi_periph
	}
	set_property CONFIG.S00_HAS_REGSLICE {1} [get_bd_cells controler_AXI_0_axi_periph]

	# Create instance: rst_pll_100M, and set properties
	set rst_pll_100M [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_pll_100M ]

	# Create instance: xlslice_0, and set properties
	set xlslice_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_0 ]
	set_property -dict [list \
		CONFIG.DIN_FROM {9} \
		CONFIG.DIN_TO {0} \
	] $xlslice_0

	# Create interface connections
	connect_bd_intf_net -intf_net controler_AXI_0_M_AXI [get_bd_intf_pins controler_AXI_0/M_AXI] [get_bd_intf_pins controler_AXI_0_axi_periph/S00_AXI]
	connect_bd_intf_net -intf_net controler_AXI_0_axi_periph_M00_AXI [get_bd_intf_pins controler_AXI_0_axi_periph/M00_AXI] [get_bd_intf_pins axi_led/S_AXI]
	connect_bd_intf_net -intf_net i_osc_clk_1 [get_bd_intf_ports i_osc] [get_bd_intf_pins pll/CLK_IN1_D]

	# Create port connections
	connect_bd_net -net axi_led_gpio_io_o [get_bd_pins axi_led/gpio_io_o] [get_bd_pins xlslice_0/Din]
	connect_bd_net -net bus_clk_1 [get_bd_ports bus_clk] [get_bd_pins controler_AXI_0_axi_periph/S00_ACLK] [get_bd_pins controler_AXI_0/m_axi_aclk]
	connect_bd_net -net controler_AXI_0_o_addr_ready [get_bd_pins controler_AXI_0/o_addr_ready] [get_bd_ports o_addr_ready]
	connect_bd_net -net controler_AXI_0_o_read_data [get_bd_pins controler_AXI_0/o_read_data] [get_bd_ports o_read_data]
	connect_bd_net -net controler_AXI_0_o_read_data_valid [get_bd_pins controler_AXI_0/o_read_data_valid] [get_bd_ports o_read_data_valid]
	connect_bd_net -net controler_AXI_0_o_write_data_ready [get_bd_pins controler_AXI_0/o_write_data_ready] [get_bd_ports o_write_data_ready]
	connect_bd_net -net i_addr_valid_1 [get_bd_ports i_addr_valid] [get_bd_pins controler_AXI_0/i_addr_valid]
	connect_bd_net -net i_bus_reset_n_1 [get_bd_ports i_bus_reset_n] [get_bd_pins pll/resetn] [get_bd_pins rst_pll_100M/ext_reset_in] [get_bd_pins controler_AXI_0_axi_periph/S00_ARESETN] [get_bd_pins controler_AXI_0/m_axi_aresetn]
	connect_bd_net -net i_common_1 [get_bd_ports i_common] [get_bd_pins controler_AXI_0/i_common]
	connect_bd_net -net i_read_data_ready_1 [get_bd_ports i_read_data_ready] [get_bd_pins controler_AXI_0/i_read_data_ready]
	connect_bd_net -net i_write_data_valid_1 [get_bd_ports i_write_data_valid] [get_bd_pins controler_AXI_0/i_write_data_valid]
	connect_bd_net -net i_write_enable_1 [get_bd_ports i_write_enable] [get_bd_pins controler_AXI_0/i_write_enable]
	connect_bd_net -net pll_clk_out1 [get_bd_pins pll/clk_out1] [get_bd_pins axi_led/s_axi_aclk] [get_bd_pins controler_AXI_0_axi_periph/M00_ACLK] [get_bd_pins rst_pll_100M/slowest_sync_clk] [get_bd_pins controler_AXI_0_axi_periph/ACLK] 
	connect_bd_net -net rst_pll_100M_peripheral_aresetn [get_bd_pins rst_pll_100M/peripheral_aresetn] [get_bd_pins axi_led/s_axi_aresetn] [get_bd_pins controler_AXI_0_axi_periph/M00_ARESETN] [get_bd_pins controler_AXI_0_axi_periph/ARESETN]
	connect_bd_net -net xlconstant_0_dout [get_bd_pins xlconstant_0/dout] [get_bd_ports o_clk_osc_inh_n]
	connect_bd_net -net xlslice_0_Dout [get_bd_pins xlslice_0/Dout] [get_bd_ports o_led]

	if { $enable_mig == 1 } {
		add_mig_instance
	}

	# Create address segments
	assign_bd_address -offset 0x40000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces controler_AXI_0/M_AXI] [get_bd_addr_segs axi_led/S_AXI/Reg] -force

	# Restore current instance
	current_bd_instance $oldCurInst

	save_bd_design
}
# End of create_root_design()


##################################################################
# MAIN FLOW
##################################################################

create_root_design "" $enable_mig


common::send_gid_msg -ssname BD::TCL -id 2053 -severity "WARNING" "This Tcl script was generated from a block design that has not been validated. It is possible that design <$design_name> may result in errors during validation."

update_compile_order -fileset $src_set

# create HDL wrapper
set wrapper_path [make_wrapper -fileset $src_set -files [get_files $design_name.bd] -top]
add_files -norecurse -fileset $src_set $wrapper_path
set_property -name "top" -value "${design_name}_wrapper" -objects $src_set



