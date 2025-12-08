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
    input wire [2:0] sw_scalar, 

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
localparam S_MENU      = 4'd0;  // SW[7:5] = 000
localparam S_INPUTER   = 4'd1;  // 001
localparam S_GENERATOR = 4'd2;  // 010
localparam S_DISPLAYER = 4'd3;  // 011
localparam S_OPERATOR  = 4'd4;  // 100
localparam S_SETTINGS  = 4'd5;  // 101

// operator sub-FSM
localparam S_OP_T      = 4'd6;
localparam S_OP_A      = 4'd7;
localparam S_OP_B      = 4'd8;
localparam S_OP_C      = 4'd9;
localparam S_OP_J      = 4'd10;

reg [3:0] state, state_next;

//======================================================================
// 2. input decode
//======================================================================
wire [2:0] menu_sel = sw[7:5];  // main menu selection
wire [2:0] op_sel   = sw[2:0];  // operator sub-function selection
wire [1:0] setting_sel = sw[4:3]; // setting selection (not used in this top module)



//======================================================================
// 3. Sequential logic (reset -> S_MENU)
//======================================================================
always @(posedge clk, negedge rst_n) begin
    if (!rst_n)
        state <= S_MENU;
    else
        state <= state_next;
end

//======================================================================
// 3. FSM combinational logic: main menu control
//======================================================================
always @(*) begin
    state_next = state;

    case (state)
        // main menu -> main functions, SW7-SW5 + confirm btn
        S_MENU: begin
            if (confirm_flag) begin
                case (menu_sel)
                    3'b000: state_next = S_MENU;
                    3'b001: state_next = S_INPUTER;
                    3'b010: state_next = S_GENERATOR;
                    3'b011: state_next = S_DISPLAYER;
                    3'b100: state_next = S_OPERATOR;
                    3'b101: state_next = S_SETTINGS;
                    default: state_next = S_MENU;
                endcase
            end
        end

        // main functions -> main functions &
        // back to menu, SW7-SW5 + confirm btn
        S_INPUTER, 
        S_GENERATOR, 
        S_DISPLAYER, 
        S_SETTINGS: begin
            if (confirm_flag) begin
                case (menu_sel)
                    3'b000: state_next = S_MENU;
                    3'b001: state_next = S_INPUTER;
                    3'b010: state_next = S_GENERATOR;
                    3'b011: state_next = S_DISPLAYER;
                    3'b100: state_next = S_OPERATOR;
                    3'b101: state_next = S_SETTINGS;
                    default: state_next = S_MENU;
                endcase
            end
        end

        // operator -> operator sub-states, SW2-SW0 + confirm btn
        S_OPERATOR: begin
            if (confirm_flag) begin
                // jump to main functions or menu
                case (menu_sel)
                    3'b000: state_next = S_MENU;
                    3'b001: state_next = S_INPUTER;
                    3'b010: state_next = S_GENERATOR;
                    3'b011: state_next = S_DISPLAYER;
                    3'b100: state_next = S_OPERATOR;
                    3'b101: state_next = S_SETTINGS;
                    default: ; // stay in current state
                endcase
                
                // jump to operator sub-states
                if (menu_sel == 3'b100) begin
                case (op_sel)
                    3'b000: state_next = S_OP_T;
                    3'b001: state_next = S_OP_A;
                    3'b010: state_next = S_OP_B;
                    3'b011: state_next = S_OP_C;
                    3'b100: state_next = S_OP_J;
                    default: ; // stay in current state
                endcase
                end
            end
        end

        // operator sub-states -> operator sub-states
        //& operator sub-states -> main functions
        S_OP_T, 
        S_OP_A, 
        S_OP_B, 
        S_OP_C, 
        S_OP_J: begin
            if (confirm_flag) begin
                // jump to main functions or menu
                case (menu_sel)
                    3'b000: state_next = S_MENU;
                    3'b001: state_next = S_INPUTER;
                    3'b010: state_next = S_GENERATOR;
                    3'b011: state_next = S_DISPLAYER;
                    3'b100: state_next = S_OPERATOR;
                    3'b101: state_next = S_SETTINGS;
                    default: ; // stay in current state
                endcase

                // jump to operator sub-states
                if (menu_sel == 3'b100) begin
                case (op_sel)
                    3'b000: state_next = S_OP_T;
                    3'b001: state_next = S_OP_A;
                    3'b010: state_next = S_OP_B;
                    3'b011: state_next = S_OP_C;
                    3'b100: state_next = S_OP_J;
                    default: ; // stay in current state
                endcase
                end
            end
        end
            
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
// 5. Seven-segment display definitions
//======================================================================
localparam SEG_I = 8'b0000_0110;
localparam SEG_G = 8'b0011_1101;
localparam SEG_D = 8'b0101_1110;
localparam SEG_O = 8'b0011_1111;
localparam SEG_S = 8'b0110_1101;

localparam SEG_T = 8'b0111_1000;
localparam SEG_A = 8'b0111_0111;
localparam SEG_B = 8'b0111_1100;
localparam SEG_C = 8'b0011_1001;
localparam SEG_J = 8'b0000_1101;
localparam SEG_BLANK = 8'b0000_0000;

//======================================================================
// 6. Seven-segment value selection (combinational)
//======================================================================
reg [7:0] dk1_value, dk4_value;
//dk1: main function indicator
always @(*) begin
    case (state)
        S_INPUTER:       dk1_value = SEG_I;
        S_GENERATOR:     dk1_value = SEG_G;
        S_DISPLAYER:     dk1_value = SEG_D;
        S_OPERATOR,
        S_OP_T, 
        S_OP_A, 
        S_OP_B, 
        S_OP_C, 
        S_OP_J:         dk1_value = SEG_O;
        S_SETTINGS:     dk1_value = SEG_S;
        default:        dk1_value = SEG_BLANK;
    endcase
end
//dk4: operator sub-function indicator
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

// dk7 & dk8: hasn't been used yet, always blank
reg [7:0] dk7_value, dk8_value;
always @(*) begin
    dk7_value = SEG_BLANK;
    dk8_value = SEG_BLANK;
end

//======================================================================
// 7. seg_scan instance (handles DK1 & DK4 scanning multiplexing)
//======================================================================
wire in_operator_mode =
       (state == S_OPERATOR) ||
       (state == S_OP_T) || (state == S_OP_A) ||
       (state == S_OP_B) || (state == S_OP_C) || (state == S_OP_J);
wire [7:0] display_dk4_value =
       in_operator_mode ? dk4_value : SEG_BLANK;

wire [7:0] seg0_scan;
wire       dk1_en_scan;
wire       dk4_en_scan;

seg_scan u_seg_scan (
    .clk    (clk),
    .rst_n  (rst_n),

    .val_a  (dk1_value),          
    .val_b  (display_dk4_value),  

    .seg    (seg0_scan),          
    .en_a   (dk1_en_scan),        
    .en_b   (dk4_en_scan)         
);

//======================================================================
// 8. Final seven-segment output mapping (VERY clean)
//======================================================================
always @(*) begin
    // ------------- DK1-DK4 (seg0 bus) -----------------
    seg0   = seg0_scan;
    dk1_en = dk1_en_scan;
    dk4_en = dk4_en_scan;

    // ------------- DK5-DK8 (seg1 bus) -----------------
    seg1   = SEG_BLANK;
    dk7_en = 0;
    dk8_en = 0;
end

//======================================================================
// 9. UART module
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