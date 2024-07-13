open_project -reset hls_sakura_aes_enc

# Add design files
add_files src/Sbox_Composite.cpp
add_files src/AES_Encrypt.cpp
# Add test bench & files
add_files -tb test/test_aes.cpp

# Set the top-level function
set_top AES128Encrypt

# ########################################################
# Create a solution
open_solution -reset solution0 -flow_target vitis

# Define technology and clock rate
# Kintex-7
set_part {xc7k160tfbg676-1}
create_clock -period "50MHz"

config_interface -m_axi_addr64=false

# pre-synthesis C/C++ simulation
csim_design
# run synthesis
csynth_design
#  post-synthesis co-simulation
cosim_design -trace_level all
# export IP for Vivado block design
export_design -format ip_catalog

exit

