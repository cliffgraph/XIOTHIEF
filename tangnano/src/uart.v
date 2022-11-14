
// 1,000,000bps(1Mbps) とする。 1bitの送信時間幅 = 1[[usec]
// data bit = 8
// stop bit = 1
// paroty = even
// flow control = none

module UartTN # (
	parameter		    TICK_US = 40		
) (
	input	reg			nreset,
	input	reg			clk,
	//
	input	reg			uart_rx,
	output	reg			uart_tx,
	//
	input	wire		memory_empty,		
	output	reg			store_memory_s,
	input	reg[23:0]	stored_data
);

	function bit getEvenParity(input bit[7:0] dt);
		getEvenParity = (1'( 4'(dt[7]+dt[6]+dt[5]+dt[4]+dt[3]+dt[2]+dt[1]+dt[0]) & 4'b0001));
	endfunction

    shortint unsigned tx_clk_cnt;
	reg[23:0]	send_data;
	reg[7:0]	byte_data[3];
	reg			even_parity[3];
	reg[4:0]	send_bit_index;

	always_comb begin
		byte_data[0][7:0] <= send_data[23:16];
		byte_data[1][7:0] <= send_data[15:8];
		byte_data[2][7:0] <= send_data[7:0];
		even_parity[0] <= getEvenParity(send_data[23:16]);
		even_parity[1] <= getEvenParity(send_data[15:8]);
		even_parity[2] <= getEvenParity(send_data[7:0]);
	end

	enum bit[3:0] { 
		UART_TX_INIT,			// 
		UART_TX_IDLE,			// 送信待機
		UART_TX_STORE_MEM_1,	// 
		UART_TX_STORE_MEM_2,	// 
		UART_TX_STARTBIT,		// 
		UART_TX_DATA_1,			// 
		UART_TX_DATA_2,			// 
		UART_TX_PARITYBIT,		// 
		UART_TX_STOP,			// 
		UART_TX_BYTEEND			// 
	} send_tx_phase;

	always_ff @ (negedge nreset, posedge clk) begin
		if( !nreset ) begin	
			tx_clk_cnt <= 16'd0;
			send_tx_phase <= UART_TX_INIT;
			//
		end
		else begin
			case(send_tx_phase)
				UART_TX_INIT: begin
					if( tx_clk_cnt == TICK_US*10 /*10us*/) begin
						tx_clk_cnt <= 16'd0;
						send_tx_phase <= UART_TX_IDLE;
					end else begin
						tx_clk_cnt <= tx_clk_cnt + 16'd1;
						uart_tx <= 1'b1;	// IDLE(H)
					end
				end
				UART_TX_IDLE: begin
					if( memory_empty ) begin
						uart_tx <= 1'b1;	// IDLE(H)
					end else begin
						send_tx_phase <= UART_TX_STORE_MEM_1;
					end
				end
				UART_TX_STORE_MEM_1: begin
					store_memory_s <= 1'b1;
					send_tx_phase <= UART_TX_STORE_MEM_2;
				end
				UART_TX_STORE_MEM_2: begin
					store_memory_s <= 1'b0;
					send_data <= stored_data;
					send_bit_index <= 5'd0;
					tx_clk_cnt <= 16'd0;
					send_tx_phase <= UART_TX_STARTBIT;
				end

				// 送信開始
				UART_TX_STARTBIT: begin
					if( tx_clk_cnt == TICK_US*1 /*1us*/) begin
						tx_clk_cnt <= 16'd0;
						send_tx_phase <= UART_TX_DATA_1;
					end else begin
						tx_clk_cnt <= tx_clk_cnt + 16'd1;
						uart_tx <= 1'b0;	// SATRT_BIT(L)
					end
				end
				UART_TX_DATA_1: begin
					if( tx_clk_cnt == TICK_US*1 /*1us*/) begin
						tx_clk_cnt <= 16'd0; 
						send_tx_phase <= UART_TX_DATA_2;
					end else begin
						tx_clk_cnt <= tx_clk_cnt + 16'd1;
						uart_tx <= byte_data[send_bit_index[4:3]][send_bit_index[2:0]];
					end
				end
				UART_TX_DATA_2: begin
					if( send_bit_index[2:0] == 3'b111 ) begin
//						send_tx_phase <= UART_TX_PARITYBIT;
						send_tx_phase <= UART_TX_STOP;
						// send_bit_index <= send_bit_index + 5'd1; // UART_TX_STOP
					end else begin
						send_bit_index <= send_bit_index + 5'd1;
						send_tx_phase <= UART_TX_DATA_1;
					end
				end
				UART_TX_PARITYBIT: begin
					if( tx_clk_cnt == TICK_US*1 /*1us*/) begin
						tx_clk_cnt <= 16'd0;
						send_tx_phase <= UART_TX_STOP;
					end else begin
						uart_tx <= even_parity[send_bit_index[4:3]];
						tx_clk_cnt <= tx_clk_cnt + 16'd1;
					end
				end
				UART_TX_STOP: begin
					if( tx_clk_cnt == TICK_US*1 /*1us*/) begin
						tx_clk_cnt <= 16'd0;
						send_bit_index <= send_bit_index + 5'd1;
						send_tx_phase <= UART_TX_BYTEEND;
					end else begin
						tx_clk_cnt <= tx_clk_cnt + 16'd1;
						uart_tx <= 1'b1;	// STOP_BIT(H)
					end
				end
				UART_TX_BYTEEND: begin
					if( send_bit_index[4:3] == 2'd3 ) begin
						send_tx_phase <= UART_TX_IDLE;
					end else begin
						send_tx_phase <= UART_TX_STARTBIT;
					end
				end
			endcase
		end
	end
endmodule










