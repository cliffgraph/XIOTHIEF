
module MemoryTN (
	input	reg			nreset,
	input	reg			clk,
	//
	input	reg			push_s,
	input	reg[23:0]	push_dt,
	input	reg			pop_s,
	output	reg[23:0]	pop_dt,
	output	reg			empty,
	output	reg			full
	
);

	// BSRAM 1つ = 18Kbits(2304Bytes)	
	// 6KBは、BSRAMを2.6個（つまり3個)使用する
	bit[23:0]	mem[1024*2];			// 3bytes*2K = 6KB	
	bit[10:0]	w_index, w_index_next;	// インデックスは0~2047を循環する
	bit[10:0]	r_index;

	always_comb begin
		empty <= (w_index==r_index) ? 1'b1: 1'b0;
		full <= (w_index_next==r_index) ? 1'b1: 1'b0;
	end

	always_ff @ (negedge nreset, posedge clk ) begin
		if( !nreset ) begin
			w_index_next <= 11'h01;
			w_index <= 11'h00;
			r_index <= 11'h00;
		end
		else begin
			if( push_s ) begin
				mem[w_index] <= push_dt;
				w_index <= w_index + 11'h01;
				w_index_next <= w_index_next + 11'h01;
			end
			if( pop_s ) begin
				pop_dt <= mem[r_index];
				r_index <= r_index + 11'h01;
			end
		end
	end

endmodule










