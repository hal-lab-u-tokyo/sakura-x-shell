//
//    Copyright (C) 2024 The University of Tokyo
//    
//    File:          /workspace/sakura-x-shell/sakura-x-shell-ctrl/ctrl_top.v
//    Project:       tkojima
//    Author:        Takuya Kojima in The University of Tokyo (tkojima@hal.ipc.i.u-tokyo.ac.jp)
//    Created Date:  14-03-2024 14:21:17
//    Last Modified: 21-03-2024 10:03:52
//

`timescale 1ns / 1ps
`include "def.v"

module ctrl_top #(
	// timing params (default: 50MHz is assumed)
	parameter SYSCLOCK_PERIOD = 20 // needed for timing control for FT2232H
) (
	// reset
	input reset_n,

	// clock source d
	input i_clk_osc,
	output o_clk_osc_inh_n,

	// on-board LEDs
	output [9:0] o_led,

	// FTDI FIFO channel
	input i_ftdi_rxf_n,
	input i_ftdi_txe_n,
	output o_ftdi_rd_n,
	output o_ftdi_wr_n,
	output o_ftdi_siwua,
	inout [7:0] io_ftdi_adbus,

	// interconnect
	output o_bus_clk,
	output o_bus_reset_n,
	output o_addr_valid,
	output o_write_enable,
	output o_write_data_valid,
	input  i_addr_ready,
	input  i_write_data_ready,
	input  i_read_data_valid,
	output o_read_data_ready,
	output [`WORD_B] o_common, //shared for addr and write data
	input [`WORD_B] i_read_data
);
	wire clk;

	// Buffer -> FTDI
	wire w_buf2ftdi_empty;
	wire [`BYTE_B] w_buf2ftdi_data;
	wire w_ftdi2buf_read_enable;
	wire [`BYTE_B] w_bridge2buf_data;
	wire w_buf2bridge_full;
	wire w_bridge2buf_write_enable;

	fifo buffer_to_ftdi (
		.clk(clk),
		.reset_n(reset_n),
		.i_data(w_bridge2buf_data),
		.i_write_enable(w_bridge2buf_write_enable),
		.o_full(w_buf2bridge_full),
		.o_data(w_buf2ftdi_data),
		.i_read_enable(w_ftdi2buf_read_enable),
		.o_empty(w_buf2ftdi_empty),
		.o_almost_empty()
	);

	// FTDI -> Buffer
	wire w_buf2ftdi_full;
	wire [`BYTE_B] w_ftdi2buf_data;
	wire w_ftdi2buf_write_enable;
	wire [`BYTE_B] w_buf2bridge_data;
	wire w_buf2bridge_empty;
	wire w_bridge2buf_read_enable;
	wire w_buf2bridge_almost_empty;
	fifo buffer_from_ftdi (
		.clk(clk),
		.reset_n(reset_n),
		.i_data(w_ftdi2buf_data),
		.i_write_enable(w_ftdi2buf_write_enable),
		.o_full(w_buf2ftdi_full),
		.o_data(w_buf2bridge_data),
		.i_read_enable(w_bridge2buf_read_enable),
		.o_empty(w_buf2bridge_empty),
		.o_almost_empty(w_buf2bridge_almost_empty)
	);

	// interface to FT2232H
	ft2232_fifo_interface #(
		.SYSCLOCK_PERIOD(SYSCLOCK_PERIOD)
	) ft2232_interface0 (
		.clk(clk),
		.reset_n(reset_n),
		// to/from FT2232H module
		.i_ftdi_rxf_n(i_ftdi_rxf_n),
		.i_ftdi_txe_n(i_ftdi_txe_n),
		.o_ftdi_read_enable_n(o_ftdi_rd_n),
		.o_ftdi_write_enable_n(o_ftdi_wr_n),
		.io_ftdi_data(io_ftdi_adbus),
		// to/from FIFOs
		.i_fifo_read_data(w_buf2ftdi_data),
		.i_fifo_empty(w_buf2ftdi_empty),
		.o_fifo_read_enable(w_ftdi2buf_read_enable),
		.o_fifo_write_data(w_ftdi2buf_data),
		.i_fifo_full(w_buf2ftdi_full),
		.o_fifo_write_enable(w_ftdi2buf_write_enable)
	);

	// bridge between interconnect and FIFO while decoding commands
	command_control command_control0 (
		.clk(clk),
		.reset_n(reset_n),
		// from FIFO
		.i_fifo_data(w_buf2bridge_data),
		.i_fifo_empty(w_buf2bridge_empty),
		.i_fifo_almost_empty(w_buf2bridge_almost_empty),
		.o_fifo_read_enable(w_bridge2buf_read_enable),
		// to FIFO
		.o_fifo_data(w_bridge2buf_data),
		.i_fifo_full(w_buf2bridge_full),
		.o_fifo_write_enable(w_bridge2buf_write_enable),
		// interconnect
		.o_addr_valid(o_addr_valid),
		.o_write_enable(o_write_enable),
		.o_write_data_valid(o_write_data_valid),
		.i_addr_ready(i_addr_ready),
		.i_write_data_ready(i_write_data_ready),
		.i_read_data_valid(i_read_data_valid),
		.o_read_data_ready(o_read_data_ready),
		.o_common(o_common),
		.i_read_data(i_read_data)
	);

	// sys clock generation using PLL IP
`ifdef SIM
	reg r_clk;
	initial begin
		r_clk <= 0;
	end
	always begin
		#(SYSCLOCK_PERIOD/2);
		r_clk <= ~r_clk;
	end
	assign clk = r_clk;
`else
	pll pll0(
		.CLK_IN1(i_clk_osc),
		.CLK_OUT1(clk),
		.RESET(!reset_n)
	);
`endif

	// disable inhibit function, i.e., always oscillate
	assign o_clk_osc_inh_n = `DISABLE_;

	assign o_ftdi_siwua = `DISABLE;


	assign o_led = i_read_data[9:0];

	assign o_bus_reset_n = reset_n;

	// interconnect clock
`ifdef SIM
	assign o_bus_clk = clk;
`else
	ODDR2 u0 (.D0(1'b0), .D1(1'b1), .C0(clk), .C1(~clk),
				.Q(o_bus_clk),    .CE(1'b1), .R(1'b0), .S(1'b0));
`endif

endmodule
