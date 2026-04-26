# Password Lock System – Technical Specification

**Version:** 1.0  
**Release Date:** April 27, 2026  
**Target Device:** DE10-Lite Kit (Intel MAX 10 – 10M50DAF484C7G)  
**Design Language:** System Verilog / Verilog  

---

## 1. Overview

The Password Lock System is an embedded FPGA design that uses a 4×4 matrix keypad as the input device and a 16×2 I²C LCD module as the display interface. Core functionality includes: password authentication for unlocking, password change, and operation cancellation. The design is optimized for the DE10-Lite kit with an explicit Finite State Machine (FSM) architecture, ensuring stable operation, display noise immunity, and ease of extension.

Default Password: **`1234`**.

---

## 2. Keypad Mapping (4×4 Matrix)

The 4×4 matrix keypad functions are assigned as follows:

| Key   | Function                                               |
|-------|--------------------------------------------------------|
| `0`–`9`| Input numeric digits of the password                 |
| `A`   | Confirm (Enter / OK)                                   |
| `B`   | Activate Change Password mode                          |
| `C`   | Cancel – discard current input and return to idle screen |
| `*`   | Reserved (currently unused, ensures safe FSM states)   |
| `#`   | Reserved (unused)                                      |
| `D`   | Reserved (unused)                                      |

**Note:** The system responds only to keypress events (falling edge). Reserved keys do not alter the state machine.

---

## 3. Use Case Specifications

### 3.1 Unlock Successfully

| #  | User Action                                          | System State / LCD Display (Line 1 / Line 2)                |
|----|------------------------------------------------------|-------------------------------------------------------------|
| 1  | Power‑On or after Reset                              | `"Enter Pass:     "` / `"                "`                 |
| 2  | Press four digit keys matching the current password (e.g., `1`, `2`, `3`, `4`) | Each keypress shows a `*` on the LCD (digits masked). After 4 digits: `"****            "` |
| 3  | Press key `A` (Confirm)                              | `"Checking...     "` / `"                "`                 |
| 4  | System verifies match successfully                   | `"Unlock Success! "` / `"    Welcome     "`                 |
|    |                                                      | LED `unlock_led` driven HIGH.                               |
| 5  | Auto‑timeout after 1 second                          | Returns to idle screen: `"Enter Pass:     "` / `"                "`. LED turns off. |

### 3.2 Wrong Password Entry

| #  | User Action                                          | System State / LCD Display                                     |
|----|------------------------------------------------------|---------------------------------------------------------------|
| 1  | At idle screen, press four arbitrary digits that do not match the current password (e.g., `5`, `5`, `6`, `6`) | Display shows `"****            "` on line 1.                |
| 2  | Press key `A`                                        | `"Wrong Password! "` / `"  Please Wait   "`                 |
| 3  | System holds error message for 1 second              | LED `unlock_led` remains off.                                |
| 4  | After 1 second                                       | Automatically returns to idle screen `"Enter Pass:     "`.   |

### 3.3 Change Password

| #  | User Action                                      | System State / LCD Display                                     |
|----|--------------------------------------------------|---------------------------------------------------------------|
| 1  | From idle screen, press key `B`                  | `"Enter Old Pass: "` / `"                "`                  |
| 2  | Enter the 4 digits of the CURRENT password       | Each digit is displayed as `*`.                              |
| 3  | Press key `A` to confirm old password            | – If match: proceed to step 4.                               |
|    |                                                  | – If mismatch: `"Wrong Password! "` / `"  Please Wait   "` for 1 second, then return to idle screen. |
| 4  | Old password verified successfully               | `"Enter New Pass: "` / `"                "`                  |
| 5  | Enter 4 digits for the NEW password (e.g., `9`, `8`, `7`, `6`) | Each digit is displayed as `*`.                            |
| 6  | Press key `A` to save new password               | `"Pass Changed!   "` / `"  Successfully  "`                  |
|    |                                                  | LED `unlock_led` remains off.                                |
| 7  | End                                              | System returns to idle screen; the new password takes effect immediately. |

### 3.4 Cancel Operation

| #  | User Action                                    | System State / LCD Display                                     |
|----|------------------------------------------------|---------------------------------------------------------------|
| 1  | During digit entry (unlock or change password) | Press key `C` at any time.                                    |
| 2  |                                                | All entered data is discarded; system instantly returns to idle screen: `"Enter Pass:     "` / `"                "`. |

---

## 4. Hardware Requirements and Setup

- **Target Kit:** Terasic DE10‑Lite, FPGA Intel MAX 10 `10M50DAF484C7G`.
- **Clock:** Apply a 50 MHz clock signal to the `clk` pin (using the on‑board oscillator).
- **Reset (rst_n):**  
  - Reset signal is **Active‑Low**.  
  - Connect `rst_n` to a push button on the kit, e.g., `KEY0`.  
  - The system is held in reset when the button is pressed (LOW level) and operates when released (HIGH).  
- **GPIO – I²C (LCD 16×2):**  
  - The `SDA` and `SCL` lines of the I²C LCD module must be connected to FPGA GPIO pins with external pull‑up resistors suitable for 3.3V logic level.  
  - The I²C slave address (commonly `0x27` or `0x3F`) must be correctly configured inside the `lcd_display.v` module.  
- **Indicator LED:**  
  - `unlock_led`: driven HIGH upon successful unlock. Can be assigned to any on‑board LED (e.g., `LEDR0`).  
- **Display Noise Immunity:** The FSM block that updates display content operates completely independently from the I²C data transmission state machine, preventing any flickering or ghosting artifacts.

---

## 5. Implementation Notes

- During password entry, each valid numeric keypress is immediately masked on the display as a `*` character for security.  
- All fixed display strings must be exactly 16 characters long (padded with spaces if necessary).  
- The 1‑second timer used to hold success/failure messages is derived from the 50 MHz system clock.  
- All FSM transitions are triggered by keypress events (falling edge), except for the automatic timeout that returns to the idle screen.  
- The reserved keys (`*`, `#`, `D`) produce no reaction and leave the system in its current safe state.

---

*--- End of Document ---*