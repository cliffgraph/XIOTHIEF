`default_nettype none

module XIOTHIEF (
	input	reg[7:0]	msx_dt,
	input	reg[15:0]	msx_ad,
	input	reg			msx_n_sltsl,
	input	reg			msx_n_iorq,
	input	reg			msx_n_wr,
	input	reg			msx_n_rd,
	input	reg			msx_n_reset,
	input	reg			msx_clock,
	input	reg			uart_rx,		// 9: RX (DONE)
	output	reg			uart_tx,		// 8: TX (ECONFIG_N)
	input	reg			n_reset_button
);

	bit sys_n_reset;
	assign sys_n_reset = msx_n_reset & n_reset_button;

    `define TICK_US 40
	// 40tickで1[us]を示す(40MHz)

    reg sysclk;
    Gowin_OSC #(
    ) u_osc(
        .oscout(sysclk)
    );

	bit	mem_wr;
	bit[1:0] sreg_mem_wr;

	bit	iorq_wr;
	bit	iorq_rd;
	bit[1:0] sreg_iorq_wr;
	bit[1:0] sreg_iorq_rd;

	always_ff @ (negedge sys_n_reset, posedge sysclk) begin
		if( !sys_n_reset ) begin
			mem_wr <= 1'b0;
			iorq_wr <= 1'b0;
			iorq_rd <= 1'b0;
		end
		else begin
			sreg_mem_wr	<= {sreg_mem_wr[0], !msx_n_sltsl & !msx_n_wr};
			sreg_iorq_wr <= {sreg_iorq_wr[0], !msx_n_iorq & !msx_n_wr};
			sreg_iorq_rd <= {sreg_iorq_rd[0], !msx_n_iorq & !msx_n_rd};
			mem_wr <= (sreg_mem_wr == 2'b01 ) ? 1'b1 : 1'b0;
			iorq_wr <= (sreg_iorq_wr == 2'b01 ) ? 1'b1 : 1'b0;
			iorq_rd <= (sreg_iorq_rd == 2'b10 ) ? 1'b1 : 1'b0;
		end
	end

	enum bit[2:0] { 
		FETCH_WAIT0,
		FETCH_PUSH_1,
		FETCH_PUSH_2,
		FETCH_REG99H,
		FETCH_REG9BH
	} fetch_phase;

	bit[7:0]	fetched_opll_ad;
	bit[7:0]	fetched_psg_ad;
	bit			push_s;
	bit[23:0]	push_data;

	bit[1:0]	vdp_reg99h_index;	// 0-1
	bit[7:0]	vdp_reg99h[2];
	bit[7:0]	vdp_reg9Bh;
	bit[7:0]	vdp_reg_R15;
	bit[7:0]	vdp_reg_R17;
	bit			vdp_reg_incmode;

	// VSYNC検出のたびにインクリメントするカウンタ 23 bits
	bit[22:0]	vsync_frame;

	always_ff @ (negedge sys_n_reset, posedge sysclk) begin
		if( !sys_n_reset ) begin	
			fetch_phase <= FETCH_WAIT0;
			push_s		<= 1'b0;
			push_data	<= 24'h00;
			//
			vdp_reg99h_index <= 2'b0;
			vdp_reg99h[0]	<= 8'h00;
			vdp_reg99h[1]	<= 8'h00;
			vdp_reg9Bh		<= 8'h00;
			vdp_reg_R15		<= 8'h00;
			vdp_reg_R17		<= 8'h00;			
			vdp_reg_incmode	<= 1'b1;
			//
			vsync_frame		<= 23'h0000;

		end
		else begin
			case (fetch_phase) 
				FETCH_WAIT0 : begin
					// SCC(Memory)書き込みの監視
					if( mem_wr ) begin
						priority casex (msx_ad[15:0])
 							16'h9000: begin
								push_data <= {8'b0000_1000, 8'h00, msx_dt};
								fetch_phase <= FETCH_PUSH_1;
							end
 							16'h98xx: begin
								push_data <= {8'b0000_1001, msx_ad[7:0], msx_dt};
								fetch_phase <= FETCH_PUSH_1;
							end
 							16'hB000: begin
								push_data <= {8'b0000_1010, 8'h00, msx_dt};
								fetch_phase <= FETCH_PUSH_1;
							end
 							16'hB8xx: begin
								push_data <= {8'b0000_1011, msx_ad[7:0], msx_dt};
								fetch_phase <= FETCH_PUSH_1;
							end
 							16'hBFFE: begin
								push_data <= {8'b0000_1100, 8'hFE, msx_dt};
								fetch_phase <= FETCH_PUSH_1;
							end
							default: begin
								// do nothing
							end
						endcase
					end
					// I/Oポート(OPLL,PSG)へ書き込みの監視
					else if( iorq_wr ) begin
						priority case (msx_ad[7:0]) 
							8'h7C: begin	// OPLL ADDRESS REG.
								fetched_opll_ad <= msx_dt;
							end
							8'h7D: begin	// OPLL DATA REG.
								push_data <= {8'b0000_0011, fetched_opll_ad, msx_dt};
								fetch_phase <= FETCH_PUSH_1;
							end
							8'hA0: begin	// PSG  ADDRESS REG.
								fetched_psg_ad <= msx_dt;
							end
							8'hA1: begin	// PSG DATA REG.
								push_data <= {8'b0000_0100, fetched_psg_ad, msx_dt};
								// PSG汎用ポート(R14-R15)へのアクセスは無視する
								if( fetched_psg_ad < 8'h0e ) begin
									fetch_phase <= FETCH_PUSH_1;
								end
							end
							//
							8'h99: begin	// VDP: Write to control register.
								vdp_reg99h[vdp_reg99h_index] <= msx_dt;
								if( vdp_reg99h_index == 2'd1 ) begin
									vdp_reg99h_index <= 2'd0;
									fetch_phase <= FETCH_REG99H;
								end
								else begin
									vdp_reg99h_index <= vdp_reg99h_index + 2'd1;
								end
							end
							8'h9B: begin	// VDP: Write to Indirect address register.
								vdp_reg9Bh <= msx_dt;
								fetch_phase <= FETCH_REG9BH;
							end
							default: begin
								// do nothing
							end

						endcase
					end
					// VDP(I/Oポート)の読み込みの監視
					else if( iorq_rd ) begin
						priority case (msx_ad[7:0]) 
							8'h99: begin	// VDP: Read from status register.
								if( vdp_reg_R15 == 8'b0000_0000 && msx_dt[7] ) begin	// #S0
									// VSYNC!!
									// Write frame number.
									vsync_frame	<= vsync_frame + 23'h0001;
									push_data <= {1'b1, vsync_frame[22:0]};
									fetch_phase <= FETCH_PUSH_1;
								end
							end
							default: begin
								// do nothing
							end
						endcase
					end

				end

				FETCH_PUSH_1: begin
					if( !memory_full ) begin
						push_s <= 1'b1;
					end
					fetch_phase <= FETCH_PUSH_2;
				end

				FETCH_PUSH_2: begin
					push_s <= 1'b0;
					fetch_phase <= FETCH_WAIT0;
				end

				FETCH_REG99H: begin
					priority if( vdp_reg99h[1] == 8'b1000_1111 ) begin	// R15
						vdp_reg_R15 <= vdp_reg99h[0];
					end
					else if( vdp_reg99h[1] == 8'b1001_0001 ) begin		// R17
						vdp_reg_R17 <= vdp_reg99h[0];
					end
					fetch_phase <= FETCH_WAIT0;
				end

				FETCH_REG9BH: begin
					if( vdp_reg_R17[5:0] == 6'b00_1111)
						vdp_reg_R15 <= vdp_reg9Bh;
					if( vdp_reg_R17[7:6] == 2'b00)
						vdp_reg_R17 <= vdp_reg_R17 + 8'h1;
					fetch_phase <= FETCH_WAIT0;
				end

				default: begin
					// do nothing
				end

			endcase
		end
	end


	bit			memory_empty;
	bit			memory_full;
	bit			pop_s;
	bit[23:0]	pop_data;

    MemoryTN #(
    ) u_memory (
		.nreset				( sys_n_reset	),
		.clk				( sysclk		),
		//
		.push_s				( push_s		),
		.push_dt			( push_data		),
		.pop_s				( pop_s			),
		.pop_dt				( pop_data		),
		.empty				( memory_empty	),
		.full				( memory_full	)
	);

	UartTN # (
		.TICK_US			( `TICK_US		)
    ) u_uart (
		.nreset				( sys_n_reset	),
		.clk				( sysclk		),
		.uart_rx			( uart_rx		),
		.uart_tx			( uart_tx		),
		//
		.memory_empty		( memory_empty	),
		.store_memory_s		( pop_s			),
		.stored_data		( pop_data		)
	);

endmodule