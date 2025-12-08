//==============================================================================================================
// File Name    : tpu_uart_ctrl_dataflow.v
// Module Name  : tpu_uart_ctrl_dataflow
// Author       : Su Zhenyu
// Version      : 0.5
// Modified     : 2025/02/26 10:00
// Description  : A data flow control for uart & TPU data interreaction
// Function List:
//     1. save data from uart_rx to fifo
//     2. sent data from fifo to uart_tx
//     3. control the data flow & rx tx control signals
//===============================================================================================================
   
    `timescale 1ns/1ps

//===============================================================================================================
//-----------------------------------------------DIFINE EABLE FUNCTIONS------------------------------------------
//===============================================================================================================
    `define UD #1
    //`define DEBUGGER_DF_ARR

    //------------------------
    //    `define DEBUGGER_UART_TX    // For Uart ctrl both sysArr weight load and data load test                    [pass]                                 
    //------------------------
         //`define DEBUGGER_W_BUFF
         //`define DEBUGGER_R_BUFF

//===============================================================================================================
//-----------------------------------------------MODULE DEFINE FUNCTIONS-----------------------------------------
//===============================================================================================================

    module tpu_uart_ctrl_dataflow#(
        //------ parameter define -----
        parameter WBUFF_WIDTH = 8,
        parameter WBUFF_DEPTH = 4,
        parameter MATRIX_COL  = 2,
        parameter MATRIX_ROW  = 2,

        parameter DATA_IN_PIPE= 3,
        parameter DBUFF_WIDTH = 8,
        parameter DBUFF_DEPTH = 6
    )
    (
        `ifdef DEBUGGER_DF_ARR
          output reg [3:0] debug,
        `elsif DEBUGGER_UART_TX
               `ifdef DEBUGGER_W_BUFF
                  input  wire[1:0] obuff_sele,
                  output reg [3:0] debugger,
                `endif
        `endif
        //-------Global Clock and Reset ------// i:
            input               clk_tpu,      //   200MHz TPU Clock
            input               clk_uart,     //   50MHz UART Clock
            input               rst_n  ,      //   Reset Ngetive
    
        //-------UART Signals ----------------// i:
            input      [7:0]    uart_rx_data, //   UART Receive Data
            input               uart_rx_en  , //   UART Receive Data Valid
            
                                              // o:
            output     [7:0]    byte_out    , //   UART Transmit Data
            output              byte_valid  , //   UART Transmit Data Valid
        //-------Buff Signals ----------------// i:
            
                                              // o:
            output              wbuff_full,   //   Wight  Buffer Full
            output              dbuff_full,   //   Data   Buffer Full
            output              obuff_full,   //   Output Buffer Full
            
        //-------Button Signals --------------// i:
            input               wbuff_sele,   //   Button wight_sele:choose wight datafifo
            input               wight_load,   //   Button wight_load:create wight dataflow
            input               dbuff_sele,   //   Button data_sele:choose data datafifo
            input               data_load ,   //   Button data_load:load data dataflow and calculate
            input               uart_tx_load, //   Button uart_tx_load:arrange dataflow for uart_tx
        
        //-------TPU  Signals ----------------------------------// i:
            input  [MATRIX_COL-1:0]             active_tpu_out ,
            input  [2*MATRIX_COL*DBUFF_WIDTH-1:0] macc_tpu_out   ,
                                                                // o:
            output [MATRIX_COL-1:0]             wwrite_tpu     ,    //   Wight Write Control
            output [WBUFF_WIDTH*MATRIX_COL-1:0] wight_out_row  ,   //   Wight data to TPU of one ROW
            output                              dwrite_tpu     ,   //   data Write Control
            output [DBUFF_WIDTH*MATRIX_ROW-1:0] data_out_col       //   data to TPU of one COL
            
    );
     //------------------------------------
     // Function for parameter
     //------------------------------------
        function integer     log2;
            input integer     depth ;
            for(log2=0; depth>1; log2=log2+1) begin
                depth = depth >> 1 ;
            end
        endfunction

        localparam WCOUNT_WIDTH = log2(MATRIX_ROW*MATRIX_COL);
        localparam RCOUNT_WIDTH = log2(MATRIX_ROW);
        localparam DCOUNT_WIDTH = log2(MATRIX_ROW*DATA_IN_PIPE);
        localparam PCOUNT_WIDTH = log2(DATA_IN_PIPE);
     //------------------------------------
     // Sync signals to clk_tpu For WRA & DRA
     //------------------------------------
       //----wires & regs----//

        reg wbuff_sele_d1;
        reg wbuff_sele_d2; 
        reg wbuff_sele_d3;
        reg dbuff_sele_d1;
        reg dbuff_sele_d2; 
        reg dbuff_sele_d3;
        reg uart_rx_en_d1;
        reg uart_rx_en_d2;
        reg uart_rx_en_d3;
        wire uart_rx_en_tpu_wpedge = uart_rx_en_d2 & ~uart_rx_en_d3 & wbuff_sele_d3;
        wire uart_rx_en_tpu_dpedge = uart_rx_en_d2 & ~uart_rx_en_d3 & dbuff_sele_d3;
        reg wpdege_d1;
        reg dpdege_d1;
        wire uart_rx_en_tpu_w = wpdege_d1;
        wire uart_rx_en_tpu_d = dpdege_d1;

        //reg [7:0] uart_rx_data_d1;
        //reg [7:0] uart_rx_data_d2;
        //reg [7:0] uart_rx_data_d3;
        wire [7:0] uart_rx_data_tpu = uart_rx_data ; // mabe need to change

        reg wight_load_d1;
        reg wight_load_d2;
        reg wight_load_d3;
        reg data_load_d1;
        reg data_load_d2;
        reg data_load_d3;
        wire wight_load_tpu = wight_load_d2 & ~wight_load_d3;
        wire data_load_tpu = data_load_d2 & ~data_load_d3;

      //----singals delay----//
        always@(posedge clk_tpu or negedge rst_n)begin
            if(~rst_n)begin
                wbuff_sele_d1 <= 1'b0;
                wbuff_sele_d2 <= 1'b0;
                wbuff_sele_d3 <= 1'b0;
                dbuff_sele_d1 <= 1'b0;
                dbuff_sele_d2 <= 1'b0;
                dbuff_sele_d3 <= 1'b0;
                uart_rx_en_d1 <= 1'b0;
                uart_rx_en_d2 <= 1'b0;
                uart_rx_en_d3 <= 1'b0;
                wpdege_d1 <= 1'b0;
                dpdege_d1 <= 1'b0;
                // uart_rx_data_d1 <= 8'h0;
                // uart_rx_data_d2 <= 8'h0;
                // uart_rx_data_d3 <= 8'h0;
                wight_load_d1 <= 1'b0;
                wight_load_d2 <= 1'b0;
                wight_load_d3 <= 1'b0;
                data_load_d1 <= 1'b0;
                data_load_d2 <= 1'b0;
                data_load_d3 <= 1'b0;
            end
            else begin
                wbuff_sele_d1 <= wbuff_sele;
                wbuff_sele_d2 <= wbuff_sele_d1;
                wbuff_sele_d3 <= wbuff_sele_d2;
                dbuff_sele_d1 <= dbuff_sele;
                dbuff_sele_d2 <= dbuff_sele_d1;
                dbuff_sele_d3 <= dbuff_sele_d2;
                uart_rx_en_d1 <= uart_rx_en;
                uart_rx_en_d2 <= uart_rx_en_d1;
                uart_rx_en_d3 <= uart_rx_en_d2;
                wpdege_d1 <= uart_rx_en_tpu_wpedge;
                dpdege_d1 <= uart_rx_en_tpu_dpedge;
                // uart_rx_data_d1 <= uart_rx_data;
                // uart_rx_data_d2 <= uart_rx_data_d1;
                // uart_rx_data_d3 <= uart_rx_data_d2;
                wight_load_d1 <= wight_load;
                wight_load_d2 <= wight_load_d1;
                wight_load_d3 <= wight_load_d2;
                data_load_d1 <= data_load;
                data_load_d2 <= data_load_d1;
                data_load_d3 <= data_load_d2;
            end
        end

        `ifdef DEBUGGER_DF_ARR
          reg [3:0] wdebug;
          reg [3:0] ddebug;

            always@(posedge clk_tpu or negedge rst_n)begin
                if(~rst_n)begin
                    debug  <= 4'b0;
                end
                else begin
                    if(wbuff_sele_d3&&(!dbuff_sele_d3))begin
                         
                        debug  <= wdebug;
                    end
                    else if(dbuff_sele_d3&&(!wbuff_sele_d3)) begin
                        debug <= ddebug;
                    end
                    else begin
                        debug <= 4'b0;
                    end
                end
            end
        `endif
        
     //------------------------------------
     // Wight Recive and Arrange
     //------------------------------------
        wire wight_arr_finish;
    
        rec_uart_df_ctrl #(
            .BUFFER_DEPTH (WBUFF_DEPTH           ),  // Decided by row*col
            .OUTPUT_CYCLES(MATRIX_ROW            ),  // Decided by row
            .OUT_WIDTH    (WBUFF_WIDTH*MATRIX_COL),  // uart 8bits data*COL = out width
            .OUT_BYTES_PER_CLK(MATRIX_COL        )   // Decided by row
        ) wight_uart_df_ctrl (
            `ifdef DEBUGGER_DF_ARR
              .debug      (wdebug),
            `endif
            .clk        (clk_tpu),
            .rstn       (rst_n),
            .start_arr  (wight_load_tpu),
            .rx_data    (uart_rx_data_tpu),
            .rx_en      (uart_rx_en_tpu_w),
            .out_data   (wight_out_row),
            .out_valid  (),
            .out_en     (wight_arr_finish),
            .buffer_full(wbuff_full)
        );
        generate
            genvar col;
            for(col=0; col<MATRIX_COL; col=col+1)begin
                assign wwrite_tpu[col] = wight_arr_finish;
            end
        endgenerate

     //------------------------------------
     // Data Recive and Arrange
     //------------------------------------
        wire data_arr_finish;

        rec_uart_df_ctrl #(
            .BUFFER_DEPTH (DBUFF_DEPTH           ),  // Decided by row*col
            .OUTPUT_CYCLES(DATA_IN_PIPE          ),  // Decided by row
            .OUT_WIDTH    (DBUFF_WIDTH*MATRIX_ROW),  // uart 8bits data*row = out width
            .OUT_BYTES_PER_CLK(MATRIX_ROW        )   // Decided by row
        ) data_uart_df_ctrl (
            `ifdef DEBUGGER_DF_ARR
              .debug      (ddebug),
            `endif
            .clk        (clk_tpu),
            .rstn       (rst_n),
            .start_arr  (data_load_tpu),
            .rx_data    (uart_rx_data_tpu),
            .rx_en      (uart_rx_en_tpu_d),
            .out_data   (data_out_col),
            .out_valid  (),
            .out_en     (data_arr_finish),
            .buffer_full(dbuff_full)
        );

        assign dwrite_tpu = data_arr_finish;
     
     //------------------------------------
     // Sync signals for SysArrO_RA 
     //------------------------------------

        reg uart_tx_load_d1;
        reg uart_tx_load_d2;
        reg uart_tx_load_d3;
        wire start_arr = uart_tx_load_d2 &&(!uart_tx_load_d3);
        wire [2*MATRIX_COL*DBUFF_WIDTH-1:0]sysArr_data=macc_tpu_out;
        wire sysArr_en = |active_tpu_out;

        always@(posedge clk_uart or negedge rst_n)begin
            if(!rst_n)begin
                uart_tx_load_d1 <= 0;
                uart_tx_load_d2 <= 0;
                uart_tx_load_d3 <= 0;
            end
            else begin
                uart_tx_load_d1 <= uart_tx_load   ;
                uart_tx_load_d2 <= uart_tx_load_d1;
                uart_tx_load_d3 <= uart_tx_load_d2;
            end
        end

     //------------------------------------
     // SysArr Output Recive and Arrange
     //------------------------------------

        tra_uart_df_ctrl #(
            .INPUT_WIDTH (2*DBUFF_WIDTH*MATRIX_COL),
            .BUFFER_DEPTH(DATA_IN_PIPE          ),
            .OUT_WIDTH   (DBUFF_WIDTH           )
        ) tpuout_uart_df_ctrl (
            `ifdef DEBUGGER_UART_TX
               `ifdef DEBUGGER_W_BUFF
                  .obuff_sele(obuff_sele),
                  .debugger  (debugger  ),
                `endif
            `endif
            .clk_tpu    (clk_tpu ),
            .clk_uart   (clk_uart),
            .rstn       (rst_n   ),
            .start_arr  (start_arr),
            .sysArr_data(sysArr_data),
            .sysArr_en  (sysArr_en),
            .out_data   (byte_out),
            .out_valid  (byte_valid),
            .buffer_full(obuff_full)   
        );

        
        
    endmodule
 