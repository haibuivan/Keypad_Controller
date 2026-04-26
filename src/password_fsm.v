/*******************************************************************************
* author:       haihbv
* date:         2026-04-26
* module:       password_fsm
********************************************************************************/

module password_fsm (
    input  wire clk,                    // clock
    input  wire rst_n,                  // active-low
    input  wire [3:0]  key_code,        // giá trị khi nhấn phím
    input  wire key_valid,              // key_valid để biết khi nào vừa nhấn phím
    output reg [127:0] row1,            // hàng 1 của lcd 128 kí tự
    output reg [127:0] row2,            // hàng 2 của lcd 128 kí tự
    output reg         unlock_led       // đèn báo mở khóa
);

    // khi vừa bấm phím thì key_valid = 1, khi nhả ra thì key_valid = 0 
    // tránh việc giữ phím bị đọc nhiều lần
    reg key_valid_d; // nhớ
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) key_valid_d <= 1'b0;
        else key_valid_d <= key_valid; // lưu giá trị cũ vào key_valid_d
    end
    wire key_press = key_valid & ~key_valid_d; // key_press = 1 khi vừa bấm phím

    // frame fsm 
    localparam [3:0] IDLE         = 4'd0, // không làm gì
                     ENTER_PASS   = 4'd1, // nhập mật khẩu
                     CHECK_PASS   = 4'd2, // kiểm tra mật khẩu
                     UNLOCKED     = 4'd3, // mở khóa
                     WRONG_PASS   = 4'd4, // sai mật khẩu
                     CHG_OLD      = 4'd5, // nhập mật khẩu cũ
                     CHG_CHK_OLD  = 4'd6, // kiểm tra mật khẩu cũ
                     CHG_NEW      = 4'd7, // nhập mật khẩu mới
                     CHG_SUCCESS  = 4'd8; // đổi mật khẩu thành công

    reg [3:0] state, next_state;

    reg [15:0] saved_pass;           // mật khẩu thật
    reg [15:0] input_pass;           // mật khẩu người dùng đang nhập
    reg [2:0]  input_cnt;            // đếm số ký tự đã nhập (0-4)

    // delay 1 giây để báo sai mật khẩu
    reg [26:0] delay_cnt;
    wire delay_done = (delay_cnt == 27'd50_000_000); // 1 giây với 50MHz

    // decode fsm
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            saved_pass <= 16'h1234;  // mật khẩu mặc địch 
            input_pass <= 16'h0000;
            input_cnt  <= 3'd0;
            delay_cnt  <= 27'd0;
            unlock_led <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    // reset 
                    unlock_led <= 1'b0;
                    input_cnt  <= 3'd0;
                    input_pass <= 16'h0000;
                    delay_cnt  <= 27'd0;

                    // nếu nhấn phím 
                    if (key_press) begin
                        if (key_code <= 4'h9) begin // chỉ lấy các số từ 0-9
                            input_pass <= {input_pass[11:0], key_code}; // mỗi lần nhấn phím đẩy số cũ sang trái, thêm số mới vào phải giống shift left
                            input_cnt  <= input_cnt + 1'b1;             // mỗi lấy bấm tăng số lượng ký tự
                            state <= ENTER_PASS;                        // chuyển sang trạng thái nhập mật khẩu
                        end else if (key_code == 4'hB) begin // phím B: đổi mật khẩu
                            state <= CHG_OLD;
                        end
                    end
                end

                // nhập mật khẩu
                ENTER_PASS: begin
                    if (key_press) begin
                        if (key_code <= 4'h9 && input_cnt < 4) begin
                        input_pass <= {input_pass[11:0], key_code};     // mỗi lần nhấn phím đẩy số cũ sang trái, thêm số mới vào phải giống shift left
                        input_cnt  <= input_cnt + 1'b1;                 // mỗi lấy bấm tăng số lượng ký tự
                        end else if (key_code == 4'hC) begin            // phím C: Xóa/Cancel
                            state <= IDLE;
                        end else if (key_code == 4'hA) begin            // phím A: Enter/Submit
                            if (input_cnt == 4) state <= CHECK_PASS;
                        end
                    end
                end

                // kiểm tra mật khẩu 
                CHECK_PASS: begin
                    if (input_pass == saved_pass) begin
                        state <= UNLOCKED;
                    end else begin
                        state <= WRONG_PASS;
                    end
                end

                // mở khóa thành công
                UNLOCKED: begin
                    unlock_led <= 1'b1;                                 // bật đèn báo mở khóa
                    if (delay_done) state <= IDLE;                      // delay 1s rồi quay về IDLE
                    else delay_cnt <= delay_cnt + 1'b1;
                end

                // sai mật khẩu
                WRONG_PASS: begin
                    if (delay_done) state <= IDLE;
                    else delay_cnt <= delay_cnt + 1'b1;
                end

                // nhập mật khẩu cũ
                CHG_OLD: begin
                    if (key_press) begin
                        if (key_code <= 4'h9 && input_cnt < 4) begin
                            input_pass <= {input_pass[11:0], key_code};
                            input_cnt  <= input_cnt + 1'b1;
                        end else if (key_code == 4'hC) begin
                            state <= IDLE;
                        end else if (key_code == 4'hA) begin
                            if (input_cnt == 4) state <= CHG_CHK_OLD;
                        end
                    end
                end

                // kiểm tra mật khẩu cũ
                CHG_CHK_OLD: begin
                    if (input_pass == saved_pass) begin
                        state <= CHG_NEW;
                        input_cnt  <= 3'd0;
                        input_pass <= 16'h0000;
                    end else begin
                        state <= WRONG_PASS; // Báo sai rồi quay về IDLE
                    end
                end

                // nhập mật khẩu mới
                CHG_NEW: begin
                    if (key_press) begin
                        if (key_code <= 4'h9 && input_cnt < 4) begin
                            input_pass <= {input_pass[11:0], key_code};
                            input_cnt  <= input_cnt + 1'b1;
                        end else if (key_code == 4'hC) begin
                            state <= IDLE;
                        end else if (key_code == 4'hA) begin
                            if (input_cnt == 4) begin
                                saved_pass <= input_pass; // Lưu pass mới
                                state      <= S_CHG_SUCCESS;
                                delay_cnt  <= 27'd0;
                            end
                        end
                    end
                end

                // đổi mật khẩu thành công
                CHG_SUCCESS: begin
                    if (delay_done) state <= IDLE;
                    else delay_cnt <= delay_cnt + 1'b1;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // hiển thị số lượng ký tự đã nhập
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

    // hiển thị LCD
    always @(*) begin
        case (state)
            IDLE: begin
                row1 = "Enter Pass:     ";
                row2 = "  A:OK B:Change ";
            end
            ENTER_PASS: begin
                row1 = "Enter Pass:     ";
                row2 = star_str;
            end
            CHECK_PASS: begin
                row1 = "Checking...     ";
                row2 = "                ";
            end
            UNLOCKED: begin
                row1 = "Unlock Success! ";
                row2 = "    Welcome     ";
            end
            WRONG_PASS: begin
                row1 = "Wrong Password! ";
                row2 = "  Please Wait   ";
            end
            CHG_OLD: begin
                row1 = "Enter Old Pass: ";
                row2 = star_str;
            end
            CHG_CHK_OLD: begin
                row1 = "Checking...     ";
                row2 = "                ";
            end
            CHG_NEW: begin
                row1 = "Enter New Pass: ";
                row2 = star_str;
            end
            CHG_SUCCESS: begin
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
