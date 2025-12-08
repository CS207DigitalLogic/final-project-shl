//==============================================================================================================
// File Name    : tra_uart_df_ctrl.v
// Module Name  : tra_uart_df_ctrl
// Author       : Su Zhenyu
// Version      : 0.1
// Modified     : 2025/03/02 10:00
// Description  : buffer and arrange the sysArr output Matrix data 
// Function List:
//  1.catech the Output Matrix data
//  2.arrange the Output Matrix data
//  3.output the Output Matrix data to uart_tx
//===============================================================================================================
    `timescale 1ns/1ps
//===============================================================================================================
//-----------------------------------------------DIFINE EABLE FUNCTIONS------------------------------------------
//===============================================================================================================
    //------------------------
        `define DEBUGGER_UART_TX    // For Uart ctrl both sysArr weight load and data load test                    [pass]                                 
    //------------------------
         //`define DEBUGGER_W_BUFF
         //`define DEBUGGER_R_BUFF

//===============================================================================================================
//-----------------------------------------------MODULE DEFINE FUNCTIONS-----------------------------------------
//===============================================================================================================

module tra_uart_df_ctrl #(
    parameter INPUT_WIDTH    = 16,    // Input data width (sysArr output)
    parameter BUFFER_DEPTH   = 3,     // Buffer depth in bytes
    parameter OUT_WIDTH      = 8      // UART output width
)(
    //-------------------DEBUGGER------------------------//
    `ifdef DEBUGGER_UART_TX
        `ifdef DEBUGGER_W_BUFF
            input  wire[1:0] obuff_sele,
            output reg [3:0] debugger,
        `endif
    `endif
    //------------------- System clocks-------------------//
    input  wire        clk_tpu,                           // TPU clock domain (200MHz)
    input  wire        clk_uart,                          // UART clock domain (50MHz)
    input  wire        rstn,
    
    //----------------- Control signals-------------------//
    input  wire        start_arr,                         // Start transmission
    
    //--------- Data input (TPU clock domain)-------------//
    input  wire [INPUT_WIDTH-1:0] sysArr_data,
    input  wire        sysArr_en,
    
    //--------- Data output (UART clock domain)-----------//
    output reg  [OUT_WIDTH-1:0] out_data,
    output reg          out_valid,
    output wire         buffer_full
);

//---------------------------
// PARAMETERS & FUNCTIONS
//---------------------------
integer i;
localparam BYTES_PER_WORD = INPUT_WIDTH/OUT_WIDTH;

function integer log2;
    input integer depth;
    begin
        for(log2=0; depth>1; log2=log2+1)
            depth = depth >> 1;
    end
endfunction

//---------------------------
// CLOCK DOMAIN: TPU (Write Side)
//---------------------------
reg [INPUT_WIDTH-1:0] tpu_buffer [0:BUFFER_DEPTH-1];
reg [log2(BUFFER_DEPTH):0] wr_ptr;
wire tpu_buffer_full;

// Gray code conversion for clock domain crossing
reg [log2(BUFFER_DEPTH):0] wr_ptr_gray;
always @(posedge clk_tpu) begin
    wr_ptr_gray <= wr_ptr ^ (wr_ptr >> 1);
end

// Write control
reg send_finish;
always @(posedge clk_tpu or negedge rstn) begin
    if(!rstn) begin
        wr_ptr <= 0;
        for( i=0; i<BUFFER_DEPTH; i=i+1)
            tpu_buffer[i] <= 0;
    end else if(sysArr_en && !tpu_buffer_full) begin
        tpu_buffer[wr_ptr] <= sysArr_data;
        wr_ptr <= wr_ptr + 1;
    end
    else if(send_finish)begin
        wr_ptr <= 0;
    end
end

assign tpu_buffer_full = (wr_ptr >= BUFFER_DEPTH);

//---------------------------
// CLOCK DOMAIN CROSSING
//---------------------------
(* ASYNC_REG = "TRUE" *) reg [log2(BUFFER_DEPTH):0] wr_ptr_gray_sync0, wr_ptr_gray_sync1;
always @(posedge clk_uart) begin
    wr_ptr_gray_sync0 <= wr_ptr_gray;
    wr_ptr_gray_sync1 <= wr_ptr_gray_sync0;
end

// Convert back to binary
reg [log2(BUFFER_DEPTH):0] wr_ptr_sync;
always @(*) begin
    wr_ptr_sync = wr_ptr_gray_sync1;
    for( i=0; i<log2(BUFFER_DEPTH); i=i+1)
        wr_ptr_sync = wr_ptr_sync ^ (wr_ptr_gray_sync1 >> (i+1));
end

//---------------------------
// CLOCK DOMAIN: UART (Read Side)
//---------------------------
reg [INPUT_WIDTH-1:0] uart_buffer [0:BUFFER_DEPTH-1];
reg [log2(BUFFER_DEPTH):0] rd_ptr;

// Double buffer synchronization
always @(posedge clk_uart) begin
    if(rd_ptr == 0) begin // Safe to update
        for( i=0; i<BUFFER_DEPTH; i=i+1)
            uart_buffer[i] <= tpu_buffer[i];
    end
end

//---------------------------
// OUTPUT STATE MACHINE
//---------------------------

parameter IDLE        = 2'd0;
parameter OUTPUT_BYTE = 2'd1;
parameter NEXT_WORD   = 2'd2;

reg[1:0] curr_state;
reg [log2(BYTES_PER_WORD):0] byte_cnt;
reg [log2(BUFFER_DEPTH):0] word_cnt;


always @(posedge clk_uart or negedge rstn) begin
    if(!rstn) begin
        out_valid <= 0;
        out_data <= 0;
        curr_state <= IDLE;
        rd_ptr <= 0;
        byte_cnt <= 0;
        word_cnt <= 0;
        send_finish<=0;
    end else begin
        case(curr_state)
            IDLE: begin
                out_valid <= 0;
                send_finish<=0;
                if(start_arr && (wr_ptr_sync > 0)) begin
                    rd_ptr <= 0;
                    word_cnt <= 0;
                    curr_state <= OUTPUT_BYTE;
                end
            end
            
            OUTPUT_BYTE: begin
                out_valid <= 1;
                // Select current byte
                //out_data <= uart_buffer[word_cnt] >> (byte_cnt*OUT_WIDTH);
                out_data <= uart_buffer[word_cnt] >> ((BYTES_PER_WORD-1-byte_cnt)*OUT_WIDTH);
                
                if(byte_cnt == BYTES_PER_WORD-1) begin
                    byte_cnt <= 0;
                    word_cnt <= word_cnt + 1;
                    curr_state <= NEXT_WORD;
                end else begin
                    byte_cnt <= byte_cnt + 1;
                end
            end
            
            NEXT_WORD: begin
                if(word_cnt >= wr_ptr_sync) begin
                    curr_state <= IDLE;
                    out_valid <= 0;
                    send_finish<=1;
                end else begin
                    curr_state <= OUTPUT_BYTE;
                    out_valid <= 0;
                end
            end
        endcase
    end
end

//---------------------------
// BUFFER STATUS
//---------------------------
assign buffer_full = tpu_buffer_full;

//---------------------------
// DEBUGGER
//---------------------------
`ifdef DEBUGGER_UART_TX
    `ifdef DEBUGGER_W_BUFF
        always@(*)begin
            case(obuff_sele)
                2'b00: debugger = uart_buffer[0];
                2'b01: debugger = uart_buffer[1];
                2'b10: debugger = uart_buffer[2];
                2'b11: debugger = 4'hF;
            endcase
        end
    `endif
`endif

endmodule
