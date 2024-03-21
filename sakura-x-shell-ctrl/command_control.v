`include "def.v"

module command_control (
	input clk,
	input reset_n,
	// from fifo
	input [`BYTE_B] i_fifo_data,
	input i_fifo_empty,
	output o_fifo_read_enable,
	input i_fifo_almost_empty,
	// to fifo
	output [`BYTE_B] o_fifo_data,
	input i_fifo_full,
	output o_fifo_write_enable,
	// to interconnect
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

	// command decode
	reg [`CMD_W-1:0] r_command;
	reg [2:0] r_cmd_byte_count;
	wire [`PREPOST_AMBLE_W-1:0] w_preamble, w_postamble;
	wire [`CMD_TYPE_W-1:0] w_cmd_type;
	wire [`CMD_TYPE_ATTR_W-1:0] w_cmd_type_attr;
	wire [`CMD_ARGS_W-1:0] w_cmd_args;
	assign {w_preamble, w_cmd_type, w_cmd_type_attr, w_cmd_args, w_postamble} = r_command;

	wire w_error_cmd;
	assign w_error_cmd = (w_preamble != `PREAMBLE) || (w_postamble != `POSTAMBLE);
	wire w_read_cmd, w_write_cmd, w_reset_cmd;
	assign w_read_cmd = (w_cmd_type == `CMD_READ);
	assign w_write_cmd = (w_cmd_type == `CMD_WRITE);
	assign w_reset_cmd = (w_cmd_type == `CMD_RESET) && w_cmd_type_attr == 0;
	wire w_unknown_cmd;
	assign w_unknown_cmd = !w_read_cmd && !w_write_cmd && !w_reset_cmd;

	// ack data
	wire [`BYTE_B] w_ack_data;
	assign w_ack_data = (w_error_cmd) ? `RESPOINSE_CMD_ERR :
						(w_unknown_cmd) ? `RESPOINSE_UNKNOWN_CMD_ERR :
						`RESPOINSE_OK;

	// read, write status
	reg [`WORD_B] r_addr;
	reg [`CMD_TYPE_ATTR_W-1:0] r_word_count, r_word_size;
	reg [`WORD_B] r_read_data, r_write_data;
	reg [2:0] r_byte_count;
	// big endian
	wire [`BYTE_B] w_read_byte = r_read_data[8 * r_byte_count +: 8];

	// state machine
	reg r_fifo_read_enable;
	localparam STATE_W = 11;
	localparam STATE_WAIT_B = 0;
	localparam STATE_WAIT = 1 << STATE_WAIT_B;						// 0x01
	localparam STATE_GET_COMMAND_B = 1;
	localparam STATE_GET_COMMAND = 1 << STATE_GET_COMMAND_B;		// 0x02
	localparam STATE_ACK_COMMAND_B = 2;
	localparam STATE_ACK_COMMAND = 1 << STATE_ACK_COMMAND_B;		// 0x04
	localparam STATE_SET_READ_ADDR_B = 3;
	localparam STATE_SET_READ_ADDR = 1 << STATE_SET_READ_ADDR_B;	// 0x08
	localparam STATE_READ_DATA_B = 5;
	localparam STATE_READ_DATA = 1 << STATE_READ_DATA_B;			// 0x20
	localparam STATE_READ_DATA_ACK_B = 6;
	localparam STATE_READ_DATA_ACK = 1 << STATE_READ_DATA_ACK_B;	// 0x40
	localparam STATE_READ_DATA_SEND_B = 7;
	localparam STATE_READ_DATA_SEND = 1 << STATE_READ_DATA_SEND_B;	// 0x80
	localparam STATE_SET_WRITE_ADDR_B = 8;
	localparam STATE_SET_WRITE_ADDR = 1 << STATE_SET_WRITE_ADDR_B;	// 0x100
	localparam STATE_FETCH_WRITE_DATA_B = 9;
	localparam STATE_FETCH_WRITE_DATA = 1 << STATE_FETCH_WRITE_DATA_B;	// 0x200
	localparam STATE_WRITE_DATA_B = 10;
	localparam STATE_WRITE_DATA = 1 << STATE_WRITE_DATA_B;			// 0x400


	reg [STATE_W-1:0] r_state;

	always @(posedge clk or negedge reset_n) begin
		if (!reset_n) begin
			r_state <= STATE_WAIT;
			r_word_count <= 0;
			r_word_size <= 0;
		end else begin
			case (r_state)
				STATE_WAIT: begin
					if (!i_fifo_empty) begin
						r_state <= STATE_GET_COMMAND;
					end
				end
				STATE_GET_COMMAND: begin
					if (r_cmd_byte_count == `CMD_BYTE_LEN - 1) begin
						// command received
						r_state <= STATE_ACK_COMMAND;
					end else if (!i_fifo_almost_empty) begin
						// next byte
						r_state <= STATE_GET_COMMAND;
					end else begin
						// wait for next byte
						r_state <= STATE_WAIT;
					end
				end
				STATE_ACK_COMMAND: begin
					// wait until fifo is not full to send ack
					if (!i_fifo_full) begin
						if (w_error_cmd || w_unknown_cmd) begin
							// error
							r_state <= STATE_WAIT;
						end else begin
							if (w_read_cmd) begin
								// read command
								r_state <= STATE_SET_READ_ADDR;
								r_word_size <= w_cmd_type_attr;
								r_word_count <= 0;
							end else if (w_write_cmd) begin
								// write command
								r_state <= STATE_SET_WRITE_ADDR;
								r_word_size <= w_cmd_type_attr;
								r_word_count <= 0;
							end else if (w_reset_cmd) begin
								// reset command
								r_state <= STATE_WAIT;
							end
						end
					end
				end
				STATE_SET_READ_ADDR: begin
					if (i_addr_ready) begin
						r_state <= STATE_READ_DATA;
					end
				end
				STATE_READ_DATA: begin
					if (i_read_data_valid) begin
						r_state <= STATE_READ_DATA_ACK;
					end
				end
				STATE_READ_DATA_ACK: begin
					r_state <= STATE_READ_DATA_SEND;
				end
				STATE_READ_DATA_SEND: begin
					if (!i_fifo_full) begin
						if (r_byte_count == 0) begin // last byte enqueued
							if (r_word_count == r_word_size) begin
								r_state <= STATE_WAIT;
							end else begin
								r_word_count <= r_word_count + 1;
								r_state <= STATE_SET_READ_ADDR;
							end
						end
					end
				end
				STATE_SET_WRITE_ADDR: begin
					if (i_addr_ready) begin
						r_state <= STATE_FETCH_WRITE_DATA;
					end
				end
				STATE_FETCH_WRITE_DATA: begin
					if (!i_fifo_empty && r_byte_count == 0) begin
						r_state <= STATE_WRITE_DATA;
					end
				end
				STATE_WRITE_DATA: begin
					if (i_write_data_ready) begin
						if (r_word_count == r_word_size) begin
							r_state <= STATE_WAIT;
						end else begin
							r_state <= STATE_SET_WRITE_ADDR;
							r_word_count <= r_word_count + 1;
						end
					end
				end
			endcase
		end
	end

	// command buffer
	always @(posedge clk or negedge reset_n) begin
		if (!reset_n) begin
			r_command <= 0;
			r_cmd_byte_count <= 0;
		end else if (r_state[STATE_GET_COMMAND_B]) begin
			r_command <= {r_command[`CMD_W-`BYTE_W-1:0], i_fifo_data};
			if (r_cmd_byte_count == `CMD_BYTE_LEN - 1) begin
				r_cmd_byte_count <= 0;
			end else begin
				r_cmd_byte_count <= r_cmd_byte_count + 1;
			end
		end
	end

	// read data buffer
	always @(posedge clk or negedge reset_n) begin
		if (!reset_n) begin
			r_read_data <= 0;
		end else if (i_read_data_valid) begin
			r_read_data <= i_read_data;
		end
	end

	// write data buffer
	always @(posedge clk or negedge reset_n) begin
		if (!reset_n) begin
			r_write_data <= 0;
		end else if (r_state[STATE_FETCH_WRITE_DATA_B] && !i_fifo_empty) begin
			r_write_data <= {r_write_data[`WORD_W-`BYTE_W:0], i_fifo_data};
		end
	end

	// byte counter
	always @(posedge clk or negedge reset_n) begin
		if (!reset_n) begin
			r_byte_count <= 0;
		end else begin
			case (r_state)
				STATE_READ_DATA_SEND: begin
					if (!i_fifo_full) begin
						r_byte_count <= r_byte_count - 1;
					end
				end
				STATE_READ_DATA_ACK: begin
					r_byte_count <= 3; // big endian
				end
				STATE_SET_WRITE_ADDR: begin
					r_byte_count <= 3;
				end
				STATE_FETCH_WRITE_DATA: begin
					if (!i_fifo_empty) begin
						r_byte_count <= r_byte_count - 1;
					end
				end
			endcase
		end
	end


	// address buffer
	always @(posedge clk or negedge reset_n) begin
		if (!reset_n) begin
			r_addr <= 0;
		end else if (r_state[STATE_ACK_COMMAND_B]) begin
			if (w_read_cmd || w_write_cmd) begin
				// latch address when read or write command is received
				r_addr <= w_cmd_args;
			end
		end
	end

	// output signals
	assign o_fifo_read_enable = r_state[STATE_GET_COMMAND_B] || r_state[STATE_FETCH_WRITE_DATA_B] && !i_fifo_empty;
	assign o_fifo_write_enable = (r_state[STATE_ACK_COMMAND_B] ||
								  r_state[STATE_READ_DATA_SEND_B]) && !i_fifo_full;
	assign o_fifo_data = (r_state[STATE_ACK_COMMAND_B]) ? w_ack_data :
						 (r_state[STATE_READ_DATA_SEND_B]) ? w_read_byte : 0;

	assign o_addr_valid = r_state[STATE_SET_READ_ADDR_B] | r_state[STATE_SET_WRITE_ADDR_B];
	assign o_write_enable = r_state[STATE_SET_WRITE_ADDR_B] | r_state[STATE_FETCH_WRITE_DATA_B] | r_state[STATE_WRITE_DATA_B];
	assign o_write_data_valid = r_state[STATE_WRITE_DATA_B];
	assign o_read_data_ready = r_state[STATE_READ_DATA_ACK_B];
	assign o_common = (!r_state[STATE_WRITE_DATA_B]) ? r_addr + r_word_count * 4 :
						r_write_data;

endmodule


// module axi4_control #
// (
// 	parameter AXI_ADDR_WIDTH = 32,
// 	parameter AXI_DATA_WIDTH = 32
// ) (
// 	input clk,
// 	input reset_n,

// 	// to/from local
// 	input i_addr_valid,
// 	input i_write_enable,
// 	input i_wdata_valid,
// 	output o_ready,
// 	input [AXI_ADDR_WIDTH-1:0] i_addr,
// 	output[AXI_DATA_WIDTH-1:0] o_read_data,
// 	input [AXI_DATA_WIDTH-1:0] i_write_data,

// 	// -- write channel
// 	output [AXI_ADDR_WIDTH-1 : 0] axi_awaddr, // address
// 	output [2 : 0] axi_awprot, // protection type
// 	output axi_awvalid, // address valid
// 	input  axi_awready, // address ready
// 	output [AXI_DATA_WIDTH-1 : 0] axi_wdata, // write data
// 	output [AXI_DATA_WIDTH/8-1 : 0] axi_wstrb, // write strobe
// 	output axi_wvalid, // write valid
// 	input  axi_wready, // write ready
// 	input  [1 : 0] axi_bresp, // write response
// 	input  axi_bvalid, // write response valid
// 	output axi_bready, // write response ready
// 	// -- read channel
// 	output [AXI_ADDR_WIDTH-1 : 0] axi_araddr, // address
// 	output [2 : 0] axi_arprot, // protection type
// 	output axi_arvalid, // address valid
// 	input  axi_arready, // address ready
// 	input  [AXI_DATA_WIDTH-1 : 0] axi_rdata, // read data
// 	input  [1 : 0] axi_rresp, // read response
// 	input  axi_rvalid, // read valid
// 	output axi_rready // read ready
// );
// 	// ================= AXI4 interface =================

// 	// ######## registers ########
// 	// write transaction
// 	reg r_axi_awvalid, r_axi_wvalid, r_axi_bready;
// 	// read transaction
// 	reg r_axi_arvalid, r_axi_rready;
// 	//write address
// 	reg [AXI_ADDR_WIDTH-1 : 0] 	r_axi_awaddr;
// 	//write data
// 	reg [AXI_DATA_WIDTH-1 : 0] 	r_axi_wdata;
// 	//read addresss
// 	reg [AXI_ADDR_WIDTH-1 : 0] 	r_axi_araddr;

// 	reg r_addr_valid, r_addr_valid_delayed;
// 	wire w_raise_addr_valid;
// 	reg r_wdata_valid, r_wdata_valid_delayed;
// 	wire w_raise_wdata_valid;
// 	wire w_read_start, w_write_start;

// 	// ######## IO connections ########
// 	assign axi_awaddr	= r_axi_awaddr;
// 	//axi 4 write data
// 	assign axi_wdata	= r_axi_wdata;
// 	assign axi_awprot	= 3'b000;
// 	assign axi_awvalid	= r_axi_awvalid;
// 	//write data(w)
// 	assign axi_wvalid	= r_axi_wvalid;
// 	// consider only word write
// 	assign axi_wstrb	= 4'b1111;
// 	//write response (b)
// 	assign axi_bready	= r_axi_bready;
// 	//read address (ar)
// 	assign axi_araddr	= r_axi_araddr;
// 	assign axi_arvalid	= r_axi_arvalid;
// 	assign axi_arprot	= 3'b001;
// 	//read and read response (r)
// 	assign axi_rready	= r_axi_rready;

// 	// internal control signal
// 	// edge detection
// 	assign w_raise_addr_valid = (!i_addr_valid) && r_addr_valid;
// 	assign w_raise_wdata_valid = (!i_wdata_valid) && r_wdata_valid;

// 	// to/from core registers
// 	reg [AXI_DATA_WIDTH-1:0] r_read_data;
// 	assign o_read_data = r_read_data;

// 	assign o_ready = r_axi_rready | r_axi_bready;

// 	always @(posedge clk) begin
// 		if (!reset_n) begin
// 			r_addr_valid <= 1'b0;
// 			r_addr_valid_delayed <= 1'b0;
// 			r_wdata_valid <= 1'b0;
// 			r_wdata_valid_delayed <= 1'b0;
// 		end else begin
// 			r_addr_valid <= i_addr_valid;
// 			r_addr_valid_delayed <= r_addr_valid;
// 			r_wdata_valid <= i_wdata_valid;
// 			r_wdata_valid_delayed <= r_wdata_valid;
// 		end
// 	end

// 	// ######## write address channel ########
// 	always @(posedge clk) begin
// 		if (!reset_n) begin
// 			r_axi_awvalid <= `DISABLE;
// 		end else begin
// 			if (w_raise_addr_valid && i_write_enable) begin
// 				r_axi_awvalid <= `ENABLE;
// 			end else if (axi_awready && r_axi_awvalid) begin
// 				// keep aserted until the slave accepts the address
// 				r_axi_awvalid <= `DISABLE;
// 			end
// 		end
// 	end

// 	// ######## Write data channel ########
// 	always @(posedge clk) begin
// 		if (!reset_n) begin
// 			r_axi_wvalid <= `DISABLE;
// 		end else if (w_raise_wdata_valid) begin
// 			//Signal a new address/data command is available by user logic
// 			r_axi_wvalid <= `ENABLE;
//  		end else if (axi_wready && r_axi_wvalid) begin
// 			//Data accepted by interconnect/slave (issue of M_AXI_WREADY by slave)
// 			r_axi_wvalid <= `DISABLE;
// 		end
// 	end


// 	// ######## Write response channel ########
// 	always @(posedge clk) begin
// 		if (!reset_n) begin
// 			r_axi_bready <= `DISABLE;
// 		end else if (axi_bvalid && ~r_axi_bready) begin
// 			// accept/acknowledge bresp with r_axi_bready by the master
// 			// when axi_bvalid is asserted by slave
// 			r_axi_bready <= `ENABLE;
// 		end else if (r_axi_bready) begin
// 		// deassert after one clock cycle
// 			r_axi_bready <= `DISABLE;
// 		end
// 	end


// 	// ######## Read address channel ########
// 	always @(posedge clk) begin
// 		if (!reset_n) begin
// 			r_axi_arvalid <= `DISABLE;
// 		end else if (w_raise_addr_valid && ~i_write_enable) begin
// 			//Signal a new read address command is available by user logic
// 			r_axi_arvalid <= `ENABLE;
// 		end	else if (axi_arready && r_axi_arvalid) begin
// 			//RAddress accepted by interconnect/slave (issue of M_AXI_ARREADY by slave)
// 			r_axi_arvalid <= `DISABLE;
// 		end
// 		// retain the previous value
// 	end

// 	// ######## Read data channel ########
// 	always @(posedge clk) begin
// 		if (!reset_n) begin
// 			r_axi_rready <= `DISABLE;
// 		end else if (axi_rready && ~r_axi_rready) begin
// 			r_axi_rready <= `ENABLE;
// 		end else if (r_axi_rready) begin
// 			// assert r_axi_rready for one clock cycle
// 			r_axi_rready <= `DISABLE;
// 		end
// 		// retain the previous value
// 	end

// 	always @(posedge clk) begin
// 		if (!reset_n) begin
// 			r_read_data <= 0;
// 		end else begin
// 			if (axi_rvalid) begin
// 				r_read_data <= axi_rdata;
// 			end
// 		end
// 	end


// 	// latch signals
// 	// Write data & address
// 	always @(posedge clk) begin
// 		if (!reset_n) begin
// 			r_axi_wdata <= 0;
// 		end else if (w_raise_wdata_valid) begin
// 			r_axi_wdata	<= i_write_data;
// 		end
// 	end

// 	always @(posedge clk) begin
// 		if (!reset_n) begin
// 			r_axi_awaddr <= 0;
// 		end else if (w_raise_addr_valid && i_write_enable) begin
// 			r_axi_awaddr <= i_addr;
// 		end
// 	end

// 	//Read Addresses
// 	always @(posedge clk) begin
// 		if (!reset_n) begin
// 			r_axi_araddr <= 0;
// 		end else if (w_raise_addr_valid && ~i_write_enable) begin
// 			r_axi_araddr <= i_addr;
// 		end
// 	end
// endmodule