#
#    Copyright (C) 2024 The University of Tokyo
#
#    File:          /vivado/mig_clock.xdc
#    Project:       sakura-x-shell
#    Author:        Takuya Kojima in The University of Tokyo (tkojima@hal.ipc.i.u-tokyo.ac.jp)
#    Created Date:  27-03-2024 20:56:44
#    Last Modified: 27-03-2024 20:56:44
#

set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets main_i/pll/inst/clk_in1_main_pll_0]
