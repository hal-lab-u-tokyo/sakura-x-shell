//
//    Copyright (C) 2026 University of Tsukuba
//    
//    File:          /hardware/sakura-x-shell/vivado/ip_repo/controller_AXI_1_0/hdl/controller_AXI_v1_0_M_AXI.v
//    Project:       chipwhisperer-enhanced-plugins
//    Author:        Takuya Kojima in University of Tsukuba (tkojima@lila.cs.tsukuba.ac.jp)
//    Created Date:  27-03-2024 21:00:44
//    Last Modified: 21-10-2026 02:49:42
//


`timescale 1 ns / 1 ps

	module controller_AXI_v1_0_M_AXI #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line

		// The master will start generating data from the C_M_START_DATA_VALUE value
		parameter  C_M_START_DATA_VALUE	= 32'h00000000,
		// The master requires a target slave base address.
		// The master will initiate read and write transactions on the slave with base address specified here as a parameter.
		parameter  C_M_TARGET_SLAVE_BASE_ADDR	= 32'h00000000,
		// Width of M_AXI address bus.
		// The master generates the read and write addresses of width specified as C_M_AXI_ADDR_WIDTH.
		parameter integer C_M_AXI_ADDR_WIDTH	= 32,
		// Width of M_AXI data bus.
		// The master issues write data and accept read data where the width of the data bus is C_M_AXI_DATA_WIDTH
		parameter integer C_M_AXI_DATA_WIDTH	= 32,
		// Transaction number is the number of write
		// and read transactions the master will perform as a part of this example memory test.
		parameter integer C_M_TRANSACTIONS_NUM	= 4
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

		// AXI clock signal
		input wire  M_AXI_ACLK,
		// AXI active low reset signal
		input wire  M_AXI_ARESETN,
		// Master Interface Write Address Channel ports. Write address (issued by master)
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_AWADDR,
		// Write channel Protection type.
		// This signal indicates the privilege and security level of the transaction,
		// and whether the transaction is a data access or an instruction access.
		output wire [2 : 0] M_AXI_AWPROT,
		// Write address valid.
		// This signal indicates that the master signaling valid write address and control information.
		output wire  M_AXI_AWVALID,
		// Write address ready.
		// This signal indicates that the slave is ready to accept an address and associated control signals.
		input wire  M_AXI_AWREADY,
		// Master Interface Write Data Channel ports. Write data (issued by master)
		output wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_WDATA,
		// Write strobes.
		// This signal indicates which byte lanes hold valid data.
		// There is one write strobe bit for each eight bits of the write data bus.
		output wire [C_M_AXI_DATA_WIDTH/8-1 : 0] M_AXI_WSTRB,
		// Write valid. This signal indicates that valid write data and strobes are available.
		output wire  M_AXI_WVALID,
		// Write ready. This signal indicates that the slave can accept the write data.
		input wire  M_AXI_WREADY,
		// Master Interface Write Response Channel ports.
		// This signal indicates the status of the write transaction.
		input wire [1 : 0] M_AXI_BRESP,
		// Write response valid.
		// This signal indicates that the channel is signaling a valid write response
		input wire  M_AXI_BVALID,
		// Response ready. This signal indicates that the master can accept a write response.
		output wire  M_AXI_BREADY,
		// Master Interface Read Address Channel ports. Read address (issued by master)
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_ARADDR,
		// Protection type.
		// This signal indicates the privilege and security level of the transaction,
		// and whether the transaction is a data access or an instruction access.
		output wire [2 : 0] M_AXI_ARPROT,
		// Read address valid.
		// This signal indicates that the channel is signaling valid read address and control information.
		output wire  M_AXI_ARVALID,
		// Read address ready.
    	// This signal indicates that the slave is ready to accept an address and associated control signals.
		input wire  M_AXI_ARREADY,
		// Master Interface Read Data Channel ports. Read data (issued by slave)
		input wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_RDATA,
		// Read response. This signal indicates the status of the read transfer.
		input wire [1 : 0] M_AXI_RRESP,
		// Read valid. This signal indicates that the channel is signaling the required read data.
		input wire  M_AXI_RVALID,
		// Read ready. This signal indicates that the master can accept the read data and response information.
		output wire  M_AXI_RREADY
	);

	localparam STATE_W = 8;
	localparam STATE_IDLE_B = 			0;
	localparam STATE_IDLE = 			(1 << STATE_IDLE_B);
	localparam STATE_WRITE_DATA_B = 	1;
	localparam STATE_WRITE_DATA = 		(1 << STATE_WRITE_DATA_B);
	localparam STATE_WRITE_TRANSFER_B = 2;
	localparam STATE_WRITE_TRANSFER = 	(1 << STATE_WRITE_TRANSFER_B);
	localparam STATE_WRITE_RESPONSE_B = 3;
	localparam STATE_WRITE_RESPONSE = 	(1 << STATE_WRITE_RESPONSE_B);
	localparam STATE_WRITE_ACK_B = 		4;
	localparam STATE_WRITE_ACK = 		(1 << STATE_WRITE_ACK_B);
	localparam STATE_READ_ADDR_B = 		5;
	localparam STATE_READ_ADDR = 		(1 << STATE_READ_ADDR_B);
	localparam STATE_READ_TRANSFER_B = 	6;
	localparam STATE_READ_TRANSFER = 	(1 << STATE_READ_TRANSFER_B);
	localparam STATE_READ_ACK_B = 		7;
	localparam STATE_READ_ACK = 		(1 << STATE_READ_ACK_B);

	reg [STATE_W-1:0] r_state;
	reg [C_M_AXI_ADDR_WIDTH-1:0] r_addr;
	reg [C_M_AXI_DATA_WIDTH-1:0] r_write_data;
	reg [31:0] r_read_data;
	reg r_addr_ready;
	reg r_axi_awvalid;
	reg r_axi_wvalid;

	assign M_AXI_AWADDR = C_M_TARGET_SLAVE_BASE_ADDR + r_addr;
	assign M_AXI_AWPROT = 3'b000;
	assign M_AXI_AWVALID = r_axi_awvalid;
	assign M_AXI_WDATA = r_write_data;
	assign M_AXI_WSTRB = {C_M_AXI_DATA_WIDTH/8{1'b1}};
	assign M_AXI_WVALID = r_axi_wvalid;
	assign M_AXI_BREADY = r_state == STATE_WRITE_RESPONSE;
	assign M_AXI_ARADDR = C_M_TARGET_SLAVE_BASE_ADDR + r_addr;
	assign M_AXI_ARPROT = 3'b001;
	assign M_AXI_ARVALID = r_state == STATE_READ_ADDR;
	assign M_AXI_RREADY = r_state == STATE_READ_TRANSFER;

	assign o_addr_ready = r_addr_ready;
	assign o_write_data_ready = r_state == STATE_WRITE_ACK;
	assign o_read_data = r_read_data;
	assign o_read_data_valid = r_state == STATE_READ_ACK;

	always @(posedge M_AXI_ACLK) begin
		if (!M_AXI_ARESETN) begin
			r_state <= STATE_IDLE;
			r_addr <= 0;
			r_write_data <= C_M_START_DATA_VALUE;
			r_read_data <= 0;
			r_addr_ready <= 1'b0;
			r_axi_awvalid <= 1'b0;
			r_axi_wvalid <= 1'b0;
		end else begin
			r_addr_ready <= 1'b0;
			if (M_AXI_AWVALID && M_AXI_AWREADY)
				r_axi_awvalid <= 1'b0;
			if (M_AXI_WVALID && M_AXI_WREADY)
				r_axi_wvalid <= 1'b0;
			case (r_state)
				STATE_IDLE: begin
					if (i_addr_valid) begin
						r_addr <= i_common;
						if (i_write_enable) begin
							r_addr_ready <= 1'b1;
							r_axi_awvalid <= 1'b1;
							r_state <= STATE_WRITE_DATA;
						end else begin
							r_state <= STATE_READ_ADDR;
						end
					end
				end
				STATE_WRITE_DATA: begin
					if (i_write_data_valid) begin
						r_write_data <= i_common;
						r_axi_wvalid <= 1'b1;
						r_state <= STATE_WRITE_TRANSFER;
					end
				end
				STATE_WRITE_TRANSFER: begin
					if (!r_axi_awvalid && !r_axi_wvalid)
						r_state <= STATE_WRITE_RESPONSE;
				end
				STATE_WRITE_RESPONSE: begin
					if (M_AXI_BVALID && M_AXI_BREADY)
						r_state <= STATE_WRITE_ACK;
				end
				STATE_WRITE_ACK: begin
					if (!i_write_data_valid)
						r_state <= STATE_IDLE;
				end
				STATE_READ_ADDR: begin
					if (M_AXI_ARVALID && M_AXI_ARREADY) begin
						r_addr_ready <= 1'b1;
						r_state <= STATE_READ_TRANSFER;
					end
				end
				STATE_READ_TRANSFER: begin
					if (M_AXI_RVALID && M_AXI_RREADY) begin
						r_read_data <= M_AXI_RDATA;
						r_state <= STATE_READ_ACK;
					end
				end
				STATE_READ_ACK: begin
					if (i_read_data_ready)
						r_state <= STATE_IDLE;
				end
				default: r_state <= STATE_IDLE;
			endcase
		end
	end

endmodule
