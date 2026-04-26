module top_module(
    input           clk,          // 50MHz từ DE10-Lite
    input           rst_n,        // Nút nhấn reset (active-low)
    output          scl,          // Xung nhịp I2C cho LCD
    inout           sda,          // Dữ liệu I2C cho LCD
    input     [3:0] col,          // Cột của Keypad 4x4
    output    [3:0] row,          // Hàng của Keypad 4x4
    output          unlock_led    // LED hiển thị trạng thái Unlock
);

    wire            clk_1MHz;
    wire            done_write;
    wire [7:0]      data;
    wire            cmd_data;
    wire            ena_write;
    wire [127:0]    row1;
    wire [127:0]    row2;

    wire [3:0]      key_code;
    wire            key_valid;

    // 1. Module Quét phím (Keypad 4x4)
    keypad_scanner keypad_scanner_inst (
        .clk        (clk),
        .col        (col),
        .row        (row),
        .key_code   (key_code),
        .key_valid  (key_valid)
    );

    // 2. Module FSM Điều khiển mật khẩu
    password_fsm password_fsm_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        .key_code   (key_code),
        .key_valid  (key_valid),
        .row1       (row1),
        .row2       (row2),
        .unlock_led (unlock_led)
    );

    clk_divider clk_1MHz_gen(
        .clk        (clk),
        .clk_1MHz   (clk_1MHz)
    );

    lcd_display lcd_display_inst(
        .clk_1MHz   (clk_1MHz),
        .rst_n      (rst_n),
        .ena        (1'b1),
        .done_write (done_write),
        .row1       (row1),
        .row2       (row2),
        .data       (data),
        .cmd_data   (cmd_data),
        .ena_write  (ena_write)
    );

    lcd_write_cmd_data lcd_write_cmd_data_inst(
        .clk_1MHz   (clk_1MHz),
        .rst_n      (rst_n),
        .data       (data),
        .cmd_data   (cmd_data),
        .ena        (ena_write),
        .i2c_addr   (7'h27),
        .sda        (sda),
        .scl        (scl),
        .done       (done_write)
    );

endmodule
