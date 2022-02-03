module IIR(clk, rst, Start, load, DIn, RAddr, data_done, WEN, Yn, WAddr, Finish);
	parameter n = 16;
	parameter m = 20;

	input clk, rst;
	input Start;
	input data_done;
	input [n-1:0]DIn;

	output WEN, load;
	output Finish;
	output [n-1:0]Yn;
	output [m-1:0]RAddr;
	output [m-1:0]WAddr;

	wire control_state;

	control_FSM control(
		.clk(clk), .rst(rst),
		.start(Start), .data_done(data_done), .load(load), .RAddr(RAddr), .state(control_state)
	);
	datapath dp(
		.clk(clk), .rst(rst),
		.command(control_state), .RAddr(RAddr), .DIn(DIn), .WEN(WEN), .Yn(Yn), .WAddr(WAddr), .finish(Finish)
	);
endmodule

module control_FSM(clk, rst, start, data_done, load, RAddr, state);
	parameter m = 20;
	parameter idle = 1'b0;
	parameter read = 1'b1;

	input clk, rst, start, data_done;

	output load, state;
	output [m-1:0]RAddr;

	reg load, state;
	reg [m-1:0]RAddr;

	reg next_load, next_state;
	reg [m-1:0]next_RAddr;

	always@(*) begin
		next_state = idle;
		next_load = 1'b0;
		next_RAddr = 0;
		case(state)
			idle: begin
				next_state = idle;
				next_RAddr = 0;
				next_load = 1'b0;
				if(start) begin
					next_state = read;
					next_RAddr = 0;
					next_load = 1'b1;
				end
			end
			read: begin
				next_state = read;
				next_RAddr = RAddr + 1;
				next_load = 1'b1;
				if(data_done) begin
					next_state = idle;
					next_RAddr = 0;
					next_load = 1'b0;
				end
			end
		endcase
	end

	always@(posedge clk or posedge rst) begin //DFF
		if(rst)begin
			state <= 1'b0;
			load <= 1'b0;
			RAddr <= {m{1'b0}};
		end else begin
			state <= next_state;
			load <= next_load;
			RAddr <= next_RAddr;
		end
	end
endmodule

module datapath(clk, rst, command, RAddr, DIn, WEN, Yn, WAddr, finish);
	parameter idle = 1'b0;
	parameter write = 1'b1;
	parameter n = 16;
	parameter m = 20;

	input clk, rst, command;
	input [m-1:0]RAddr;
	input [n-1:0]DIn;

	output WEN, finish;
	output [n-1:0]Yn;
	output [m-1:0]WAddr;

	reg WEN, finish, state;
	reg [m-1:0]WAddr;

	reg next_WEN, next_finish, next_state;
	reg [m-1:0]next_WAddr;

	reg [n-1:0]x0, x1, x2, x3, x4, x5;
	reg [n-1:0]y0, y1, y2, y3, y4;
	wire [n-1:0]next_x0, next_x1, next_x2, next_x3, next_x4, next_x5;
	wire [n-1:0]next_y0, next_y1, next_y2, next_y3, next_y4;

	wire [n+6:0]a0, a1, a2, a3, a4, a5, b0, a_all;
	wire [n+8:0]b1, b2, b3, b4, b_all;
	wire [n-1:0]DIn_fix = ~command ? {n{1'b0}} : DIn;
	wire [n-1:0]x0_abs, x1_abs, x2_abs, x3_abs, x4_abs, x5_abs;
	wire [n-1:0]y0_abs, y1_abs, y2_abs, y3_abs, y4_abs;

	assign x0_abs = x0[n-1] ? (~x0 + 1) : x0;
	assign x1_abs = x1[n-1] ? (~x1 + 1) : x1;
	assign x2_abs = x2[n-1] ? (~x2 + 1) : x2;
	assign x3_abs = x3[n-1] ? (~x3 + 1) : x3;
	assign x4_abs = x4[n-1] ? (~x4 + 1) : x4;
	assign x5_abs = x5[n-1] ? (~x5 + 1) : x5;
	assign y0_abs = y0[n-1] ? (~y0 + 1) : y0;
	assign y1_abs = y1[n-1] ? (~y1 + 1) : y1;
	assign y2_abs = y2[n-1] ? (~y2 + 1) : y2;
	assign y3_abs = y3[n-1] ? (~y3 + 1) : y3;
	assign y4_abs = y4[n-1] ? (~y4 + 1) : y4;
	
	assign a_all = (x0[n-1] ? (~a0 + 1) : a0) +
				   (x1[n-1] ? (~a1 + 1) : a1) +
				   (x2[n-1] ? (~a2 + 1) : a2) +
				   (x3[n-1] ? (~a3 + 1) : a3) +
				   (x4[n-1] ? (~a4 + 1) : a4) +
				   (x5[n-1] ? (~a5 + 1) : a5) +
				   (y0[n-1] ? (~b0 + 1) : b0);
	assign b_all = (y1[n-1] ? b1 : (~b1 + 1)) +
				   (y2[n-1] ? (~b2 + 1) : b2) +
				   (y3[n-1] ? b3 : (~b3 + 1)) +
				   (y4[n-1] ? (~b4 + 1) : b4);
	assign Yn = a_all[n+6:7] + {b_all[n+8], b_all[n+5:7]};
	
	assign a0 = {x0_abs[n-1],
				( {x0_abs[n-2:0], 7'd0} >> 6 )+
				( {x0_abs[n-2:0], 7'd0} >> 9 )+
				( {x0_abs[n-2:0], 7'd0} >> 10)+
				( {x0_abs[n-2:0], 7'd0} >> 11)+
				( {x0_abs[n-2:0], 7'd0} >> 12)+
				( {x0_abs[n-2:0], 7'd0} >> 13) };
	assign a1 = {x1_abs[n-1],
				( {x1_abs[n-2:0], 7'd0} >> 6 )+
				( {x1_abs[n-2:0], 7'd0} >> 8 )+
				( {x1_abs[n-2:0], 7'd0} >> 10)+
				( {x1_abs[n-2:0], 7'd0} >> 11)+
				( {x1_abs[n-2:0], 7'd0} >> 14) };
	assign a2 = {x2_abs[n-1],
				( {x2_abs[n-2:0], 7'd0} >> 5 )+
				( {x2_abs[n-2:0], 7'd0} >> 8 )+
				( {x2_abs[n-2:0], 7'd0} >> 9 )+
				( {x2_abs[n-2:0], 7'd0} >> 11)+
				( {x2_abs[n-2:0], 7'd0} >> 14) };
	assign a3 = {x3_abs[n-1],
				( {x3_abs[n-2:0], 7'd0} >> 5 )+
				( {x3_abs[n-2:0], 7'd0} >> 8 )+
				( {x3_abs[n-2:0], 7'd0} >> 9 )+
				( {x3_abs[n-2:0], 7'd0} >> 11)+
				( {x3_abs[n-2:0], 7'd0} >> 14) };
	assign a4 = {x4_abs[n-1],
				( {x4_abs[n-2:0], 7'd0} >> 6 )+
				( {x4_abs[n-2:0], 7'd0} >> 8 )+
				( {x4_abs[n-2:0], 7'd0} >> 10)+
				( {x4_abs[n-2:0], 7'd0} >> 11)+
				( {x4_abs[n-2:0], 7'd0} >> 14) };
	assign a5 = {x5_abs[n-1],
				( {x5_abs[n-2:0], 7'd0} >> 6 )+
				( {x5_abs[n-2:0], 7'd0} >> 9 )+
				( {x5_abs[n-2:0], 7'd0} >> 10)+
				( {x5_abs[n-2:0], 7'd0} >> 11)+
				( {x5_abs[n-2:0], 7'd0} >> 12)+
				( {x5_abs[n-2:0], 7'd0} >> 13) };
	assign b0 = {y0_abs[n-1],
				( {y0_abs[n-2:0], 7'd0} >> 2 )+
				( {y0_abs[n-2:0], 7'd0} >> 3 )+
				( {y0_abs[n-2:0], 7'd0} >> 8 )+
				( {y0_abs[n-2:0], 7'd0} >> 11)+
				( {y0_abs[n-2:0], 7'd0} >> 13)+
				( {y0_abs[n-2:0], 7'd0} >> 14) };
	assign b1 = {y1_abs[n-1],
				( {2'd0, y1_abs[n-2:0], 7'd0}      )+
				( {2'd0, y1_abs[n-2:0], 7'd0} >> 1 )+
				( {2'd0, y1_abs[n-2:0], 7'd0} >> 3 )+
				( {2'd0, y1_abs[n-2:0], 7'd0} >> 6 )+
				( {2'd0, y1_abs[n-2:0], 7'd0} >> 7 )+
				( {2'd0, y1_abs[n-2:0], 7'd0} >> 8 )+
				( {2'd0, y1_abs[n-2:0], 7'd0} >> 10)+
				( {2'd0, y1_abs[n-2:0], 7'd0} >> 11)+
				( {2'd0, y1_abs[n-2:0], 7'd0} >> 12)+
				( {2'd0, y1_abs[n-2:0], 7'd0} >> 13) };
	assign b2 = {y2_abs[n-1],
				( {2'd0, y2_abs[n-2:0], 7'd0} << 1 )+
				( {2'd0, y2_abs[n-2:0], 7'd0}      )+
				( {2'd0, y2_abs[n-2:0], 7'd0} >> 2 )+
				( {2'd0, y2_abs[n-2:0], 7'd0} >> 4 )+
				( {2'd0, y2_abs[n-2:0], 7'd0} >> 5 )+
				( {2'd0, y2_abs[n-2:0], 7'd0} >> 6 )+
				( {2'd0, y2_abs[n-2:0], 7'd0} >> 7 )+
				( {2'd0, y2_abs[n-2:0], 7'd0} >> 8 ) };
	assign b3 = {y3_abs[n-1],
				( {2'd0, y3_abs[n-2:0], 7'd0} << 2 )+
				( {2'd0, y3_abs[n-2:0], 7'd0} >> 7 )+
				( {2'd0, y3_abs[n-2:0], 7'd0} >> 9 )+
				( {2'd0, y3_abs[n-2:0], 7'd0} >> 10)+
				( {2'd0, y3_abs[n-2:0], 7'd0} >> 12) };
	assign b4 = {y4_abs[n-1],
				( {2'd0, y4_abs[n-2:0], 7'd0} << 1 )+
				( {2'd0, y4_abs[n-2:0], 7'd0} >> 1 )+
				( {2'd0, y4_abs[n-2:0], 7'd0} >> 2 )+
				( {2'd0, y4_abs[n-2:0], 7'd0} >> 7 )+
				( {2'd0, y4_abs[n-2:0], 7'd0} >> 13)+
				( {2'd0, y4_abs[n-2:0], 7'd0} >> 14) };
				
	assign next_x0 = x1;
	assign next_x1 = x2;
	assign next_x2 = x3;
	assign next_x3 = x4;
	assign next_x4 = x5;
	assign next_x5 = DIn_fix;
	assign next_y0 = y1;
	assign next_y1 = y2;
	assign next_y2 = y3;
	assign next_y3 = y4;
	assign next_y4 = Yn;

	always@(*) begin
		next_state = idle;
		next_WEN = 1'b0;
		next_finish = 1'b0;
		next_WAddr = {m{1'b0}};
		case(state)
			idle: begin
				next_state = idle;
				next_WEN = 1'b0;
				next_finish = 1'b0;
				next_WAddr = {m{1'b0}};
				if(command) begin
					next_state = write;
					next_WEN = 1'b1;
					next_finish = 1'b0;
					next_WAddr = {m{1'b0}};
				end
			end
			write: begin
				next_state = write;
				next_WEN = 1'b1;
				next_finish = 1'b0;
				next_WAddr = RAddr;
				if(~command) begin
					next_state = idle;
					next_WEN = 1'b0;
					next_finish = 1'b1;
					next_WAddr = {m{1'b0}};
				end
			end
		endcase
	end

	always@(posedge clk or posedge rst) begin //DFF
		if(rst)begin
			state <= 1'b0;
			WEN <= 1'b0;
			finish <= 1'b0;
			WAddr <= {m{1'b0}};
			x0 <= {n{1'b0}};
			x1 <= {n{1'b0}};
			x2 <= {n{1'b0}};
			x3 <= {n{1'b0}};
			x4 <= {n{1'b0}};
			x5 <= {n{1'b0}};
			y0 <= {n{1'b0}};
			y1 <= {n{1'b0}};
			y2 <= {n{1'b0}};
			y3 <= {n{1'b0}};
			y4 <= {n{1'b0}};
		end else begin
			state <= next_state;
			WEN <= next_WEN;
			finish <= next_finish;
			WAddr <= next_WAddr;
			x0 <= next_x0;
			x1 <= next_x1;
			x2 <= next_x2;
			x3 <= next_x3;
			x4 <= next_x4;
			x5 <= next_x5;
			y0 <= next_y0;
			y1 <= next_y1;
			y2 <= next_y2;
			y3 <= next_y3;
			y4 <= next_y4;
		end
	end
endmodule