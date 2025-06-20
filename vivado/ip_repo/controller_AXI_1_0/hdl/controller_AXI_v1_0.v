//
//    Copyright (C) 2024 The University of Tokyo
//
//    File:          /ip_repo/controller_AXI_1_0/hdl/controller_AXI_v1_0.v
//    Project:       sakura-x-shell
//    Author:        Takuya Kojima in The University of Tokyo (tkojima@hal.ipc.i.u-tokyo.ac.jp)
//    Created Date:  27-03-2024 21:00:57
//    Last Modified: 27-03-2024 21:00:57
//



`timescale 1 ns / 1 ps

	module controller_AXI_v1_0 #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line


		// Parameters of Axi Master Bus Interface M_AXI
		parameter  C_M_AXI_START_DATA_VALUE	= 32'h00000000,
		parameter  C_M_AXI_TARGET_SLAVE_BASE_ADDR	= 32'h00000000,
		parameter integer C_M_AXI_ADDR_WIDTH	= 32,
		parameter integer C_M_AXI_DATA_WIDTH	= 32,
		parameter integer C_M_AXI_TRANSACTIONS_NUM	= 4
	)
	(
		// Users to add ports here
		input  i_addr_valid,
		input  i_write_enable,
		input  i_write_data_valid,
		input  i_read_data_ready,
		input  [31:0] i_common,
		output [31:0] o_read_data,
		output o_addr_ready,
		output o_read_data_valid,
		output o_write_data_ready,

		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of Axi Master Bus Interface M_AXI
		input wire  m_axi_aclk,
		input wire  m_axi_aresetn,
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] m_axi_awaddr,
		output wire [2 : 0] m_axi_awprot,
		output wire  m_axi_awvalid,
		input wire  m_axi_awready,
		output wire [C_M_AXI_DATA_WIDTH-1 : 0] m_axi_wdata,
		output wire [C_M_AXI_DATA_WIDTH/8-1 : 0] m_axi_wstrb,
		output wire  m_axi_wvalid,
		input wire  m_axi_wready,
		input wire [1 : 0] m_axi_bresp,
		input wire  m_axi_bvalid,
		output wire  m_axi_bready,
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] m_axi_araddr,
		output wire [2 : 0] m_axi_arprot,
		output wire  m_axi_arvalid,
		input wire  m_axi_arready,
		input wire [C_M_AXI_DATA_WIDTH-1 : 0] m_axi_rdata,
		input wire [1 : 0] m_axi_rresp,
		input wire  m_axi_rvalid,
		output wire  m_axi_rready
	);
// Instantiation of Axi Bus Interface M_AXI
	controller_AXI_v1_0_M_AXI # ( 
		.C_M_START_DATA_VALUE(C_M_AXI_START_DATA_VALUE),
		.C_M_TARGET_SLAVE_BASE_ADDR(C_M_AXI_TARGET_SLAVE_BASE_ADDR),
		.C_M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH),
		.C_M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH),
		.C_M_TRANSACTIONS_NUM(C_M_AXI_TRANSACTIONS_NUM)
	) controller_AXI_v1_0_M_AXI_inst (
		.i_addr_valid(i_addr_valid),
		.i_write_enable(i_write_enable),
		.i_write_data_valid(i_write_data_valid),
		.i_read_data_ready(i_read_data_ready),
		.i_common(i_common),
		.o_read_data(o_read_data),
		.o_addr_ready(o_addr_ready),
		.o_read_data_valid(o_read_data_valid),
		.o_write_data_ready(o_write_data_ready),
		.M_AXI_ACLK(m_axi_aclk),
		.M_AXI_ARESETN(m_axi_aresetn),
		.M_AXI_AWADDR(m_axi_awaddr),
		.M_AXI_AWPROT(m_axi_awprot),
		.M_AXI_AWVALID(m_axi_awvalid),
		.M_AXI_AWREADY(m_axi_awready),
		.M_AXI_WDATA(m_axi_wdata),
		.M_AXI_WSTRB(m_axi_wstrb),
		.M_AXI_WVALID(m_axi_wvalid),
		.M_AXI_WREADY(m_axi_wready),
		.M_AXI_BRESP(m_axi_bresp),
		.M_AXI_BVALID(m_axi_bvalid),
		.M_AXI_BREADY(m_axi_bready),
		.M_AXI_ARADDR(m_axi_araddr),
		.M_AXI_ARPROT(m_axi_arprot),
		.M_AXI_ARVALID(m_axi_arvalid),
		.M_AXI_ARREADY(m_axi_arready),
		.M_AXI_RDATA(m_axi_rdata),
		.M_AXI_RRESP(m_axi_rresp),
		.M_AXI_RVALID(m_axi_rvalid),
		.M_AXI_RREADY(m_axi_rready)
	);

	// Add user logic here

	// User logic ends

	endmodule
