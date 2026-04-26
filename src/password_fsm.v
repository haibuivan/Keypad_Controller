module password_fsm (
    input  wire        clk,          // 50MHz clock from DE10-Lite
    input  wire        rst_n,        // Active-low reset
    input  wire [3:0]  key_code,
    input  wire        key_valid,
    output reg [127:0] row1,
    output reg [127:0] row2,
    output reg         unlock_led    // Just in case we want a hardware indicator
);

    // =========================================================================
    // 1. Edge Detection cho Keypad
    // =========================================================================
    reg key_valid_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) key_valid_d <= 1'b0;
        else        key_valid_d <= key_valid;
    end
    wire key_press = key_valid & ~key_valid_d;

    // =========================================================================
    // 2. FSM States Definition (Yêu cầu chỉ rõ FSM)
    // =========================================================================
    localparam [3:0] S_IDLE         = 4'd0,
                     S_ENTER_PASS   = 4'd1,
                     S_CHECK_PASS   = 4'd2,
                     S_UNLOCKED     = 4'd3,
                     S_WRONG_PASS   = 4'd4,
                     S_CHG_OLD      = 4'd5,
                     S_CHG_CHK_OLD  = 4'd6,
                     S_CHG_NEW      = 4'd7,
                     S_CHG_SUCCESS  = 4'd8;

    reg [3:0] state, next_state;

    // =========================================================================
    // 3. Internal Registers
    // =========================================================================
    reg [15:0] saved_pass;           // Mật khẩu hiện tại (4 nibbles)
    reg [15:0] input_pass;           // Mật khẩu người dùng đang nhập
    reg [2:0]  input_cnt;            // Đếm số ký tự đã nhập (0-4)

    // Delay counter logic
    reg [26:0] delay_cnt;
    wire       delay_done = (delay_cnt == 27'd50_000_000); // 1 giây với 50MHz

    // Register cập nhật data an toàn (Synchronous FSM)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= S_IDLE;
            saved_pass <= 16'h1234;  // Password mặc định: 1234
            input_pass <= 16'h0000;
            input_cnt  <= 3'd0;
            delay_cnt  <= 27'd0;
            unlock_led <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    unlock_led <= 1'b0;
                    input_cnt  <= 3'd0;
                    input_pass <= 16'h0000;
                    delay_cnt  <= 27'd0;

                    if (key_press) begin
                        if (key_code <= 4'h9) begin // Nhập số
                            input_pass <= {input_pass[11:0], key_code};
                            input_cnt  <= input_cnt + 1'b1;
                            state      <= S_ENTER_PASS;
                        end else if (key_code == 4'hB) begin // Phím B: Change Pass
                            state      <= S_CHG_OLD;
                        end
                    end
                end

                S_ENTER_PASS: begin
                    if (key_press) begin
                        if (key_code <= 4'h9 && input_cnt < 4) begin
                            input_pass <= {input_pass[11:0], key_code};
                            input_cnt  <= input_cnt + 1'b1;
                        end else if (key_code == 4'hC) begin // Phím C: Xóa/Cancel
                            state <= S_IDLE;
                        end else if (key_code == 4'hA) begin // Phím A: Enter/Submit
                            if (input_cnt == 4) state <= S_CHECK_PASS;
                        end
                    end
                end

                S_CHECK_PASS: begin
                    if (input_pass == saved_pass) begin
                        state <= S_UNLOCKED;
                    end else begin
                        state <= S_WRONG_PASS;
                    end
                end

                S_UNLOCKED: begin
                    unlock_led <= 1'b1;
                    if (delay_done) state <= S_IDLE;
                    else            delay_cnt <= delay_cnt + 1'b1;
                end

                S_WRONG_PASS: begin
                    if (delay_done) state <= S_IDLE;
                    else            delay_cnt <= delay_cnt + 1'b1;
                end

                S_CHG_OLD: begin
                    if (key_press) begin
                        if (key_code <= 4'h9 && input_cnt < 4) begin
                            input_pass <= {input_pass[11:0], key_code};
                            input_cnt  <= input_cnt + 1'b1;
                        end else if (key_code == 4'hC) begin
                            state <= S_IDLE;
                        end else if (key_code == 4'hA) begin
                            if (input_cnt == 4) state <= S_CHG_CHK_OLD;
                        end
                    end
                end

                S_CHG_CHK_OLD: begin
                    if (input_pass == saved_pass) begin
                        state      <= S_CHG_NEW;
                        input_cnt  <= 3'd0;
                        input_pass <= 16'h0000;
                    end else begin
                        state      <= S_WRONG_PASS; // Báo sai rồi quay về IDLE
                    end
                end

                S_CHG_NEW: begin
                    if (key_press) begin
                        if (key_code <= 4'h9 && input_cnt < 4) begin
                            input_pass <= {input_pass[11:0], key_code};
                            input_cnt  <= input_cnt + 1'b1;
                        end else if (key_code == 4'hC) begin
                            state <= S_IDLE;
                        end else if (key_code == 4'hA) begin
                            if (input_cnt == 4) begin
                                saved_pass <= input_pass; // Lưu pass mới
                                state      <= S_CHG_SUCCESS;
                                delay_cnt  <= 27'd0;
                            end
                        end
                    end
                end

                S_CHG_SUCCESS: begin
                    if (delay_done) state <= S_IDLE;
                    else            delay_cnt <= delay_cnt + 1'b1;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    // =========================================================================
    // 4. Decode Số Lượng Ký Tự (*) Ra LCD 
    // =========================================================================
    reg [127:0] star_str;
    always @(*) begin
        case (input_cnt)
            3'd0: star_str = "                ";
            3'd1: star_str = "*               ";
            3'd2: star_str = "**              ";
            3'd3: star_str = "***             ";
            3'd4: star_str = "****            ";
            default: star_str = "                ";
        endcase
    end

    // =========================================================================
    // 5. Output Logic (Hiển thị LCD) - Không ảnh hưởng LCD timing
    // =========================================================================
    always @(*) begin
        case (state)
            S_IDLE: begin
                row1 = "Enter Pass:     ";
                row2 = "  A:OK B:Change ";
            end
            S_ENTER_PASS: begin
                row1 = "Enter Pass:     ";
                row2 = star_str;
            end
            S_CHECK_PASS: begin
                row1 = "Checking...     ";
                row2 = "                ";
            end
            S_UNLOCKED: begin
                row1 = "Access Granted! ";
                row2 = "    Welcome     ";
            end
            S_WRONG_PASS: begin
                row1 = "Wrong Password! ";
                row2 = "  Please Wait   ";
            end
            S_CHG_OLD: begin
                row1 = "Enter Old Pass: ";
                row2 = star_str;
            end
            S_CHG_CHK_OLD: begin
                row1 = "Checking...     ";
                row2 = "                ";
            end
            S_CHG_NEW: begin
                row1 = "Enter New Pass: ";
                row2 = star_str;
            end
            S_CHG_SUCCESS: begin
                row1 = "Pass Changed!   ";
                row2 = "  Successfully  ";
            end
            default: begin
                row1 = "System Error    ";
                row2 = "                ";
            end
        endcase
    end

endmodule
