variable design_name
set design_name main

set errMsg ""
set nRet 0

set cur_design [current_bd_design -quiet]
set list_cells [get_bd_cells -quiet]

set scriptPath [file normalize [info script]]
set scriptDir [file dirname $scriptPath]

common::send_gid_msg -ssname BD::TCL -id 2004 -severity "INFO" "Making design <$design_name> as current_bd_design."
current_bd_design $design_name

# check IP
set aes_rtl_core_ip "user.org:user:aes128_rsm_rtl:1.0"

set ip_repo_loc [file normalize [file join $scriptDir "../ip_repo"]]
set src_set [current_fileset -quiet]
set current_ip_repo_paths [get_property "ip_repo_paths" $src_set]
# append
set aes_rtl_core_ip_repo "[file join $ip_repo_loc "aes128_rsm_rtl_1_0" ]"
if { [lsearch -exact $current_ip_repo_paths $aes_rtl_core_ip_repo] == -1 } {
	# concat space separated paths
	set current_ip_repo_paths [concat $current_ip_repo_paths $aes_rtl_core_ip_repo]
	set_property "ip_repo_paths" $current_ip_repo_paths $src_set
}
update_ip_catalog -rebuild

# add extra constraints
set constr_set [current_fileset -quiet -constrset]
import_files -fileset $constr_set [file normalize [file join $scriptDir "extra_pin_assign.xdc"]]



# update block design
set parentCell [get_bd_cells /]

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

# create ports
set running [ create_bd_port -dir O running ]

# change PLL settings
set pll [ get_bd_cells pll ]
set_property -dict [list \
	CONFIG.CLKIN1_JITTER_PS {50.0} \
	CONFIG.CLKOUT1_JITTER {112.316} \
	CONFIG.CLKOUT1_PHASE_ERROR {89.971} \
	CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {100} \
	CONFIG.CLKOUT2_JITTER {155.330} \
	CONFIG.CLKOUT2_PHASE_ERROR {89.971} \
	CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {20} \
	CONFIG.CLKOUT2_USED {true} \
	CONFIG.MMCM_CLKFBOUT_MULT_F {5.000} \
	CONFIG.MMCM_CLKIN1_PERIOD {5.000} \
	CONFIG.MMCM_CLKIN2_PERIOD {10.0} \
	CONFIG.MMCM_CLKOUT0_DIVIDE_F {10.000} \
	CONFIG.MMCM_CLKOUT1_DIVIDE {50} \
	CONFIG.NUM_OUT_CLKS {2} \
	CONFIG.PRIM_IN_FREQ {200} \
	CONFIG.PRIM_SOURCE {Differential_clock_capable_pin} \
	CONFIG.RESET_PORT {resetn} \
	CONFIG.RESET_TYPE {ACTIVE_LOW} \
	CONFIG.USE_LOCKED {true} \
] $pll

# change AXI interconect
set controller_AXI_0_axi_periph [ get_bd_cells controller_AXI_0_axi_periph ]
set_property -dict [list \
	CONFIG.NUM_MI {2} \
	CONFIG.S00_HAS_REGSLICE {1} \
] $controller_AXI_0_axi_periph


# Create instance: aes_rtl_core_0, and set properties
set aes_rtl_core_0 [ create_bd_cell -type ip -vlnv $aes_rtl_core_ip aes_rtl_core_0 ]

# Create instance: rst_pll_aes, and set properties
set rst_pll_aes [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_pll_aes ]

# interface connection
connect_bd_intf_net -intf_net controller_AXI_0_axi_periph_M01_AXI [get_bd_intf_pins controller_AXI_0_axi_periph/M01_AXI] [get_bd_intf_pins aes_rtl_core_0/S_AXI]

# port connections
connect_bd_net -net aes_rtl_core_0_o_running [get_bd_pins aes_rtl_core_0/o_running] [get_bd_ports running]

# connect nets
connect_bd_net -net pll_clk_out2 [get_bd_pins pll/clk_out2] [get_bd_pins controller_AXI_0_axi_periph/M01_ACLK] [get_bd_pins rst_pll_aes/slowest_sync_clk] [get_bd_pins aes_rtl_core_0/s_axi_aclk]

connect_bd_net -net rst_pll_aes_peripheral_aresetn [get_bd_pins rst_pll_aes/peripheral_aresetn] [get_bd_pins controller_AXI_0_axi_periph/M01_ARESETN] [get_bd_pins aes_rtl_core_0/s_axi_aresetn]

connect_bd_net [get_bd_ports i_bus_reset_n] [get_bd_pins rst_pll_aes/ext_reset_in]

connect_bd_net -net pll_locked [get_bd_pins pll/locked] [get_bd_pins rst_pll_aes/dcm_locked]


# Create address segments
assign_bd_address -offset 0x8000_0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces controller_AXI_0/M_AXI] [get_bd_addr_segs aes_rtl_core_0/S_AXI/S_AXI_reg] -force

# Restore current instance
current_bd_instance $oldCurInst

save_bd_design
