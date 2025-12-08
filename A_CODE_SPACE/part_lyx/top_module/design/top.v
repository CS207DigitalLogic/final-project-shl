`timescale 1ns / 1ps
//======================================================================
//  Module: top
//  FPGA Matrix Calculator - Top Level (Updated ver. 2)
//  Implements:
//   - Main menu FSM (7 states)
//   - Menu selection switches
//   - Operation selection switches
//   - UART setting switches
//   - Scalar multiplication input switches
//   - Error LEDs
//   - DK1, DK4, DK7, DK8 seven-seg display
//======================================================================

module top (
    input wire clk,
    input wire rst_n,

    // Switches
    input wire [7:0] sw,     // sw[7:5] menu select, sw[4:3] settings, sw[2:0] op mode

    // Buttons
    input wire S3_confirm,   // confirm button (active high)
    input wire S0_send,      // UART send button

    // UART physical IO
    input  wire uart_rx,
    output wire uart_tx,

    // UART control signals
    input  wire uart_tx_rst_n,   // UART TX reset (active low)
    input  wire uart_rx_rst_n,   // UART RX reset (active low)

    // LEDs
    output reg LED5_dim_err,      // input error: dimension overflow
    output reg LED4_val_err,      // input error: value overflow
    output reg LED3_op_err,       // operator error: invalid operation

    output reg LED1_uart_tx,      // UART TX working indicator
    output reg LED0_uart_rx,      // UART RX working indicator

    // 7-segment displays
    output reg [7:0] seg0,        // DK1-DK4 segment bus
    output reg [7:0] seg1,        // DK5-DK8 segment bus

    // digit enable
    output reg dk1_en,
    output reg dk4_en,
    output reg dk7_en,
    output reg dk8_en
);

// Internal UART work indicators
wire uart_tx_work = uart_tx_rst_n;
wire uart_rx_work = uart_rx_rst_n;

//======================================================================
// Debounce modules
//======================================================================

// confirm button debounce
wire confirm_flag;  // single-cycle pulse for FSM
debounce u_db_confirm(
    .clk(clk),
    .rst_n(rst_n),
    .key_in(S3_confirm),
    .key_flag(confirm_flag)
);

// send button debounce
wire send_flag;     // single-cycle pulse for UART TX
debounce u_db_send(
    .clk(clk),
    .rst_n(rst_n),
    .key_in(S0_send),
    .key_flag(send_flag)
);

//======================================================================
// 1. FSM state encoding
//======================================================================
localparam S_IDLE      = 4'd0;
localparam S_MENU      = 4'd1;
localparam S_INPUTER   = 4'd2;
localparam S_GENERATOR = 4'd3;
localparam S_DISPLAYER = 4'd4;
localparam S_OPERATOR  = 4'd5;
localparam S_SETTINGS  = 4'd6;

// operator sub-FSM
localparam S_OP_T      = 4'd7;
localparam S_OP_A      = 4'd8;
localparam S_OP_B      = 4'd9;
localparam S_OP_C      = 4'd10;
localparam S_OP_J      = 4'd11;

reg [3:0] state, state_next;

//======================================================================
// 2. Sequential logic (reset �� S_IDLE)
//======================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state <= S_IDLE;
    else
        state <= state_next;
end

//======================================================================
// 3. FSM combinational logic: main menu control
//======================================================================
wire [2:0] menu_sel   = sw[7:5];
wire [1:0] setting_sel = sw[4:3];
wire [2:0] op_sel     = sw[2:0];
wire [3:0] scalar_val = sw[7:4];

always @(*) begin
    state_next = state;

    case (state)
        S_IDLE: state_next = S_MENU;

        S_MENU: begin
            if (confirm_flag) begin
                case (menu_sel)
                    3'b000: state_next = S_INPUTER;
                    3'b001: state_next = S_GENERATOR;
                    3'b010: state_next = S_DISPLAYER;
                    3'b011: state_next = S_OPERATOR;
                    3'b100: state_next = S_SETTINGS;
                    default: state_next = S_MENU;
                endcase
            end
        end

        // return to menu
        S_INPUTER:   if (confirm_flag && menu_sel==3'b000) state_next = S_MENU;
        S_GENERATOR: if (confirm_flag && menu_sel==3'b001) state_next = S_MENU;
        S_DISPLAYER: if (confirm_flag && menu_sel==3'b010) state_next = S_MENU;
        S_SETTINGS:  if (confirm_flag && menu_sel==3'b100) state_next = S_MENU;

        // operator �� operator sub-states
        S_OPERATOR: begin
            if (confirm_flag) begin
                case (op_sel)
                    3'b000: state_next = S_OP_T;
                    3'b001: state_next = S_OP_A;
                    3'b010: state_next = S_OP_B;
                    3'b011: state_next = S_OP_C;
                    3'b100: state_next = S_OP_J;
                    default: state_next = S_OPERATOR;
                endcase
            end
        end

        // operator sub-states �� return to menu
        S_OP_T, S_OP_A, S_OP_B, S_OP_C, S_OP_J:
            if (confirm_flag) state_next = S_MENU;
    endcase
end

//======================================================================
// 4. LED logic
//======================================================================

// UART work indicators
always @(*) begin
    LED1_uart_tx = uart_tx_work;
    LED0_uart_rx = uart_rx_work;
end

// error indicators
always @(*) begin
    LED5_dim_err = 1'b0;
    LED4_val_err = 1'b0;
    LED3_op_err  = 1'b0;
end

//======================================================================
// 5. Seven-segment display encoding
//======================================================================
localparam SEG_I = 8'b0000_0110;
localparam SEG_G = 8'b0100_1111;
localparam SEG_D = 8'b0011_1110;
localparam SEG_O = 8'b0011_1111;
localparam SEG_S = 8'b0110_1101;

localparam SEG_T = 8'b0000_1111;
localparam SEG_A = 8'b0111_0111;
localparam SEG_B = 8'b0111_1100;
localparam SEG_C = 8'b0101_1000;
localparam SEG_J = 8'b0000_1110;
localparam SEG_BLANK = 8'b0000_0000;

reg [7:0] dk1_value;
always @(*) begin
    case (state)
        S_INPUTER:   dk1_value = SEG_I;
        S_GENERATOR: dk1_value = SEG_G;
        S_DISPLAYER: dk1_value = SEG_D;
        S_OPERATOR,
        S_OP_T, S_OP_A, S_OP_B, S_OP_C, S_OP_J:
                      dk1_value = SEG_O;
        S_SETTINGS:  dk1_value = SEG_S;
        default:     dk1_value = SEG_BLANK;
    endcase
end

reg [7:0] dk4_value;
always @(*) begin
    case (state)
        S_OPERATOR: begin
            case(op_sel)
                3'b000: dk4_value = SEG_T;
                3'b001: dk4_value = SEG_A;
                3'b010: dk4_value = SEG_B;
                3'b011: dk4_value = SEG_C;
                3'b100: dk4_value = SEG_J;
                default: dk4_value = SEG_BLANK;
            endcase
        end

        S_OP_T: dk4_value = SEG_T;
        S_OP_A: dk4_value = SEG_A;
        S_OP_B: dk4_value = SEG_B;
        S_OP_C: dk4_value = SEG_C;
        S_OP_J: dk4_value = SEG_J;

        default: dk4_value = SEG_BLANK;
    endcase
end

reg [7:0] dk7_value, dk8_value;
always @(*) begin
    dk7_value = SEG_BLANK;
    dk8_value = SEG_BLANK;
end

//======================================================================
// 7-segment output mux
//======================================================================
always @(*) begin
    seg0 = SEG_BLANK;
    seg1 = SEG_BLANK;

    dk1_en = 0;
    dk4_en = 0;
    dk7_en = 0;
    dk8_en = 0;

    if (state == S_INPUTER || state == S_GENERATOR ||
        state == S_DISPLAYER || state == S_SETTINGS)
    begin
        dk1_en = 1;
        seg0   = dk1_value;
    end

    if (state == S_OPERATOR ||
        state == S_OP_T || state == S_OP_A ||
        state == S_OP_B || state == S_OP_C || state == S_OP_J)
    begin
        dk4_en = 1;
        seg0   = dk4_value;
    end

    dk7_en = 1;
    dk8_en = 1;
end

//======================================================================
// 8. UART module
//======================================================================

// ---------------- UART RX ----------------
wire [7:0] rx_data;
wire rx_done;

uart_rx #(
    .CLK_FREQ(100_000_000),
    .BAUD_RATE(115200)
) uart_rx_inst (
    .clk(clk),
    .rst_n(uart_rx_rst_n),
    .rx(uart_rx),
    .rx_data(rx_data),
    .rx_done(rx_done)
);

// ---------------- UART TX ----------------
// FIXED: replaced old edge-detection logic with send_flag

wire tx_busy;

uart_tx #(
    .CLK_FREQ(100_000_000),
    .BAUD_RATE(115200)
) uart_tx_inst (
    .clk(clk),
    .rst_n(uart_tx_rst_n),
    .tx_start(send_flag),      
    .tx_data(sw),
    .tx(uart_tx),
    .tx_busy(tx_busy)
);

endmodule