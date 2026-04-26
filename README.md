# Reference Manual

Hệ thống điều khiển khóa mật khẩu tích hợp Keypad Ma Trận 4x4 và màn hình LCD I2C (16x2) được thiết kế bằng System Verilog/Verilog tối ưu cho Kit FPGA **DE10-Lite (10M50DAF484C7G)**.

---

## 1. Bản Đồ Phím (Keypad Mapping)
Bàn phím ma trận 4x4 được quy ước sử dụng như sau:
- **Phím `0` -> `9`**: Dùng để nhập các chữ số của mật khẩu.
- **Phím `A`**: Nhấn để Xác nhận (Lệnh Enter/OK).
- **Phím `B`**: Nhấn để kích hoạt chế độ Đổi mật khẩu chờ (Change Password).
- **Phím `C`**: Nhấn để Hủy (Cancel) các tác vụ hoặc xóa dữ liệu đang nhập để trở về lại màn hình chờ mặc định.
- **Phím `*`, `#`, `D`**: Dự phòng, hiện tại không sử dụng bảo đảm trạng thái FSM an toàn.

**Chú ý**: Mật khẩu ban đầu của hệ thống (Default Password) là: **`1234`**

---

## 2. Các Kịch Bản Thao Tác (Use Cases)

### Kịch bản 1: Mở khóa thành công (Nhập đúng mật khẩu)
1. Ở màn hình chờ, LCD hiển thị dòng chữ: `"Enter Pass:     "` 
2. Nhấn lần lượt 4 ký tự của mật khẩu đúng (Ví dụ: `1`, `2`, `3`, `4`).
3. Ứng với mỗi phím nhấn, LCD sẽ hiển thị ký hiệu `*` (giấu mật khẩu gốc).
4. Nhấn phím **`A`** (Xác nhận/OK).
5. LCD chuyển sang màn hình phân tích `"Checking...     "`.
6. Ngay sau đó, LCD báo thành công `"Access Granted! " / "    Welcome     "` và đèn `unlock_led` sẽ sáng.
7. Hệ thống tự giữ kết quả trong 1 giây để người dùng đọc tín hiệu, sau đó reset tự động về màn hình chờ ban đầu và tắt đèn LED.

### Kịch bản 2: Nhập sai mật khẩu
1. Ở màn hình chờ, bạn nhấn 4 phím số bất kỳ nhưng không khớp mật khẩu hiện tại (Ví dụ: `5`, `5`, `6`, `6`).
2. Màn hình vẫn mã hóa thành dấu `*` bảo mật.
3. Nhấn phím **`A`** để thử xác nhận.
4. LCD báo dòng chữ: `"Wrong Password! " / "  Please Wait   "`. Đèn LED mở khóa không sáng.
5. Sau đúng 1 giây, hệ thống trả lại màn hình chờ ban đầu để bạn nhập lại.

### Kịch bản 3: Thay đổi mật khẩu mới
1. Ở màn hình chờ mặc định, nhấn phím **`B`** (Nút chức năng đổi pass).
2. LCD đổi sang thông báo: `"Enter Old Pass: "`.
3. Bạn phải nhập 4 số của mật khẩu *hiện tại đang sử dụng* (ví dụ mật khẩu mặc định là `1234`) và nhấn nút xác nhận **`A`**.
    - *Chú ý*: Nếu ở bước này bạn nhập sai mật khẩu cũ, hệ thống sẽ báo Fail `"Wrong Password! "` và đá bạn văng về màn hình chờ mặc định ngay lập tức.
4. Nếu nhập chính xác mật khẩu cũ, LCD sẽ chuyển sang bảng thông báo: `"Enter New Pass: "`.
5. Lúc này, bạn có thể nhập 4 số của **Mật khẩu mới** tùy ý (Ví dụ: `9`, `8`, `7`, `6`).
6. Sau khi nhập đủ 4 số mới, nhấn phím **`A`** lần nữa để lưu. 
7. Hệ thống sẽ báo `"Pass Changed!   " / "  Successfully  "`. Kể từ lúc này, mật khẩu mới của bạn là `9876`.

### Kịch bản 4: Đăng nhập đang dang dở nhưng muốn hủy (Cancel)
1. Ở bất kỳ màn hình nào đang chờ gõ số (nhập pass mở khóa hay đổi pass mới...).
2. Chỉ cần bấm phím **`C`**, toàn bộ số bạn vừa gõ sẽ bị xóa không lưu lại. Hệ thống sẽ ngay lập tức trả về màn hình màn hình chờ an toàn `"Enter Pass   "`.

---

## 3. Chú Ý Khi Setup Phần Cứng FPGA DE10-Lite
- **Clock**: Cấp xung nhịp chuẩn hệ thống 50MHz vào cổng `clk`.
- **Reset**: Tín hiệu `rst_n` là Active-Low. Hãy cắm nó vào các nút nhấn Push Button (ví dụ `KEY0`) trên kit DE10-Lite (vì nguyên lý nút nhấn này nhả ra là HIGH(1), nhấn vào là LOW(0)).
- **I2C SDA/SCL**: Cần khai báo đúng Pull-up Resistors hoặc cấp điện áp 3.3V chuẩn cho hai chân I2C module nối qua GPIO Header.
- **Khóa LCD Chống nhiễu**: Cấu trúc thay đổi dòng text theo Event Drive (`password_fsm.v`) hoàn toàn tách biệt với quá trình truyền bit (`lcd_display.v`). Bạn không phải lo vấn đề màn hình bị nhấp nháy (flickering) hay lu mờ phần cứng. 
