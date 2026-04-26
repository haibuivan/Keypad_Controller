module keypad_scanner (
	input            clk,        // 50MHz => T = 20ns
	output reg [3:0] row,
	input      [3:0] col,        
	output reg [3:0] key_code,
	output reg       key_valid
);

reg        scan_en;
reg [14:0] div_cnt;

// scan_en = 1 sau 20ns x 25000 = 0,5ms
always @(posedge clk) begin
    if (div_cnt == 15'd24_999) begin
        div_cnt <= 0;
        scan_en <= 1;
    end else begin
        div_cnt <= div_cnt + 1;
        scan_en <= 0;
    end
end

// quet hang
reg [1:0] row_idx;

// moi lan scan_en thi quet tung hang 
always @(posedge clk) begin
    if (scan_en)
        row_idx <= row_idx + 1;
end

always @(*) begin
    case (row_idx)
        2'd0: row = 4'b1110;
        2'd1: row = 4'b1101;
        2'd2: row = 4'b1011;
        2'd3: row = 4'b0111;
		  default: row = 4'b1111;
    endcase
end

// delay 1 nhip de tin hieu on dinh
reg [1:0] row_idx_d;

always @(posedge clk) begin
    if (scan_en)
        row_idx_d <= row_idx; // luu vao row_idx_d
end

reg key_valid_raw;

always @(posedge clk) begin
    if (scan_en) begin
        key_valid_raw <= 1;
        case ({row_idx_d, ~col})
            6'b00_0001: key_code <= 4'h1; // hang 0 cot 0 => phim 1
            6'b00_0010: key_code <= 4'h2; // hang 0 cot 1 => phim 2
            6'b00_0100: key_code <= 4'h3; // hang 0 cot 2 => phim 3
            6'b00_1000: key_code <= 4'hA; // hang 0 cot 3 => phim A
            6'b01_0001: key_code <= 4'h4; // hang 1 cot 0 => phim 4 
            6'b01_0010: key_code <= 4'h5; // hang 1 cot 1 => phim 5
            6'b01_0100: key_code <= 4'h6; // hang 1 cot 2 => phim 6
            6'b01_1000: key_code <= 4'hB; // hang 1 cot 3 => phim B
            6'b10_0001: key_code <= 4'h7;	// hang 2 cot 0 => phim 7
            6'b10_0010: key_code <= 4'h8;	// hang 2 cot 1 => phim 8
            6'b10_0100: key_code <= 4'h9;	// hang 2 cot 2 => phim 9
            6'b10_1000: key_code <= 4'hC;	// hang 2 cot 3 => phim C
            6'b11_0001: key_code <= 4'hF;  // *
            6'b11_0010: key_code <= 4'h0;  // 0
            6'b11_0100: key_code <= 4'hE;  // #
            6'b11_1000: key_code <= 4'hD;  // D
            default:    key_valid_raw <= 0;
        endcase
    end
end

// ===================================
// Bộ làm mượt chống dội (Debounce)
// Bơm xung đếm 10ms (50MHz -> 500_000)
// ===================================
reg [19:0] debounce_cnt;
always @(posedge clk) begin
    if (key_valid_raw)
        debounce_cnt <= 20'd500_000; // Cứ phát hiện phím là nạp lại 10ms
    else if (debounce_cnt > 0)
        debounce_cnt <= debounce_cnt - 1; // Không thấy phím thì trừ dần
end

// Tín hiệu valid đầu ra sẽ ổn định lì ở mức 1 cho đến khi nhả phím 10ms
always @(posedge clk) begin
    key_valid <= (debounce_cnt > 0);
end

endmodule
