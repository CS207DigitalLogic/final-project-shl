//==============================================================================================================
// File Name    : rec_uart_df_ctrl.v
// Module Name  : rec_uart_df_ctrl
// Author       : Su Zhenyu
// Version      : 0.1
// Modified     : 2025/03/02 10:00
// Description  : buffer and arrange the uart rx data 
// Function List:
//  1.catech the uart rx data
//  2.arrange the uart rx data
//  3.output the uart rx data
//===============================================================================================================
`timescale 1ns / 1ps

`define SHIFT_WAY1
//`define SHIFT_WAY20
//`define DEBUGGER_DF_ARR 

module rec_uart_df_ctrl #(
    parameter BUFFER_DEPTH      = 8,                              // Byte NUM (need to be divisible by OUTPUT_CYCLES)
    parameter OUTPUT_CYCLES     = 2,                              // Arrangement cycles(depanded on the sysArr Row or COl)
    parameter OUT_WIDTH         = 16,                             // Auto get output width
    parameter OUT_BYTES_PER_CLK = 2                               // output bytes per clk
)(
    input  wire        clk,
    input  wire        rstn,
    input  wire   start_arr,
    
    // port from UART_rx
    input  wire [7:0]  rx_data,
    input  wire        rx_en,
    
    // port for  Output data
    `ifdef DEBUGGER_DF_ARR
      output reg [3:0] debug,
    `endif
    
    output reg [OUT_WIDTH-1:0] out_data    ,
    output reg                 out_valid   ,
    output wire                buffer_full ,
    output wire                out_en       // nClk sync with all output data
);

//---------------------------
// Tings about Parameter 
//---------------------------
  //----Check parameter----//
    initial begin
        if (BUFFER_DEPTH % OUTPUT_CYCLES != 0) begin
            $error("Error: BUFFER_DEPTH(%0d) must be divisible by OUTPUT_CYCLES(%0d)", 
                BUFFER_DEPTH, OUTPUT_CYCLES);
            $finish;
        end
    end
  //----func parameter----//
    function integer     log2;
        input integer     depth ;
        for(log2=0; depth>1; log2=log2+1) begin
            depth = depth >> 1 ;
        end
    endfunction
//---------------------------
// Creat the Array of shiftreg
//---------------------------
reg [7:0] shift_reg [BUFFER_DEPTH-1:0];
reg [log2(BUFFER_DEPTH):0] wr_ptr;

//---------------------------
// Write shiftreg CTRL
//---------------------------
integer i;
reg wr_ptr_rst;
always @(posedge clk or negedge rstn) begin
    if(!rstn) begin
        wr_ptr <= 0;
        for( i=0; i<BUFFER_DEPTH; i=i+1)
            shift_reg[i] <= 8'h0;
    end 
    
    else if(wr_ptr_rst)begin
        wr_ptr <= 0;
    end

    else if(rx_en && !buffer_full) 
    begin
        // Decide SHIFT method
        `ifdef SHIFT_WAY1
            for( i=BUFFER_DEPTH-1; i>0; i=i-1)begin
              shift_reg[i] <= shift_reg[i-1];
            end   
            shift_reg[0] <= rx_data;
        
        `endif
        
        wr_ptr <= (wr_ptr == BUFFER_DEPTH) ? 0 : wr_ptr + 1;
    end 
end

//---------------------------
// FSM for OUTPUT
//---------------------------
parameter IDLE       = 0 ;
parameter OUTPUTTING = 1 ;

reg curr_state = IDLE ;

reg [log2(OUTPUT_CYCLES):0] cycle_cnt;

generate 
  if(OUTPUT_CYCLES==3)begin
    always @(posedge clk or negedge rstn) begin
        if(!rstn) begin
            out_valid <= 0;
            out_data <= 0;
            curr_state <= IDLE;
            cycle_cnt <= 0;
            wr_ptr_rst <=0; 
        end else begin
            case(curr_state)
                IDLE: begin
                    wr_ptr_rst <=0;
                    if((wr_ptr == BUFFER_DEPTH)&&start_arr) begin
                        curr_state <= OUTPUTTING;
                        cycle_cnt <= 0;
                        out_valid <= 1'b1;
                        out_data  <= 0;  // initial output 
                    end
                end
                
                OUTPUTTING: begin
                    if(cycle_cnt == OUTPUT_CYCLES) begin
                        curr_state <= IDLE;
                        out_valid <= 1'b0;
                        wr_ptr_rst<= 1'b1; 
                    end else begin
                        cycle_cnt <= cycle_cnt + 1;
                        wr_ptr_rst<= 1'b0; 
                        case(cycle_cnt)
                        2'd0:out_data  <= {shift_reg[0],shift_reg[1]};
                        2'd1:out_data  <= {shift_reg[2],shift_reg[3]};
                        2'd2:out_data  <= {shift_reg[4],shift_reg[5]};
                        default:out_data  <= 0;
                        endcase
                    end
                end

                default: begin
                    out_valid <= 0;
                    out_data <= 0;
                    curr_state <= IDLE;
                    cycle_cnt <= 0;
                    wr_ptr_rst <=0; 
                end
            endcase
        end
    end
  end

  else if(OUTPUT_CYCLES==2) begin
        always @(posedge clk or negedge rstn) begin
        if(!rstn) begin
            out_valid <= 0;
            out_data <= 0;
            curr_state <= IDLE;
            cycle_cnt <= 0;
            wr_ptr_rst <=0; 
        end else begin
            case(curr_state)
                IDLE: begin
                    wr_ptr_rst <=0;
                    if((wr_ptr == BUFFER_DEPTH)&&start_arr) begin
                        curr_state <= OUTPUTTING;
                        cycle_cnt <= 0;
                        out_valid <= 1'b1;
                        out_data  <= 0;  // initial output 
                    end
                end
                
                OUTPUTTING: begin
                    if(cycle_cnt == OUTPUT_CYCLES) begin
                        curr_state <= IDLE;
                        out_valid <= 1'b0;
                        wr_ptr_rst<= 1'b1; 
                    end else begin
                        cycle_cnt <= cycle_cnt + 1;
                        wr_ptr_rst<= 1'b0; 
                        case(cycle_cnt)
                        2'd0:out_data  <= {shift_reg[0],shift_reg[1]};
                        2'd1:out_data  <= {shift_reg[2],shift_reg[3]};
                        //2'd2:out_data  <= {shift_reg[4],shift_reg[5]};
                        default:out_data  <= 0;
                        endcase
                    end
                end

                default: begin
                    out_valid <= 0;
                    out_data <= 0;
                    curr_state <= IDLE;
                    cycle_cnt <= 0;
                    wr_ptr_rst <=0; 
                end
            endcase
        end
    end
  end

  else begin
    
  end
endgenerate

//---------------------------
// State for buffer full
//---------------------------
assign buffer_full = (wr_ptr == BUFFER_DEPTH);

//---------------------------
// Output enable
//---------------------------
  reg out_valid_d1;
  reg out_valid_d2;
  //assign out_en = out_valid_d1 && !out_valid_d2;
  always @(posedge clk or negedge rstn) begin
    if(!rstn) begin
        out_valid_d1 <= 0;
        out_valid_d2 <= 0;
    end else begin
        out_valid_d1 <= out_valid   ;
        out_valid_d2 <= out_valid_d1;
    end
  end 
//--------------------------
// OUTEN for OUTPUT_CYCLES
//--------------------------
    wire out_en_gen = out_valid_d1 && !out_valid_d2;

    generate 
        if((OUTPUT_CYCLES==2)||(OUTPUT_CYCLES==3))begin

            reg out_en_gen_d1;
            always@(posedge clk or negedge rstn)begin
                if(!rstn) begin
                out_en_gen_d1 <= 0;
                end else begin
                out_en_gen_d1 <= out_en_gen;
                end
            end
            assign  out_en = out_en_gen || out_en_gen_d1;
        
        end
    
        else begin
        end
    endgenerate

//---------------------------
// Debug
//---------------------------
`ifdef DEBUGGER_DF_ARR
  always @(posedge clk or negedge rstn) begin
    if(!rstn) begin
        debug <= 0;
    end else begin
        debug <= shift_reg[BUFFER_DEPTH-1];
    end
  end
`endif
endmodule
