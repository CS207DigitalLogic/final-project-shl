//==============================================================================================================
// File Name    : uart_tx_ctrl_gen.v
// Module Name  : uart_tx_ctrl_gen
// Author       : Su Zhenyu
// Version      : 0.5
// Modified     : 2025/03/04 16:00
// Description  : generate ctrl signals for uart tx
// Function List:
//     1. save data from sysArr to mem
//     3. control the data flow & tx control signals
//===============================================================================================================
   `timescale 1ns/1ps

//======================================================================
//-----------------------DIFINE EABLE FUNCTIONS-------------------------
//======================================================================
    `define UD #1
//======================================================================
//-----------------------MODULE DEFINE FUNCTIONS------------------------
//======================================================================
module uart_tx_ctrl_gen#(
        parameter DBUFF_DEPTH = 12
    )
    (
        input               clk  ,
        input               rst_n,
        input      [7:0]    read_data,
        input               read_en,
        input               work_start,//key[4]
        input               tx_busy,
        input      [7:0]    write_max_num,// 10
        output              buffer_full,
        output reg [7:0]    write_data,
        output reg          write_en
    );
        //------------------------------------------------------------------
        // set uart_tx working area
        //------------------------------------------------------------------
        reg work_start_d1;
        reg work_start_d2;
        wire work_start_f;
        assign work_start_f = (!work_start_d1) && (work_start_d2);
        always @(posedge clk or negedge rst_n)
        begin
            if(!rst_n)begin
                work_start_d1<=`UD 0;
                work_start_d2<=`UD 0;
            end
            else begin
                work_start_d1<=`UD work_start;
                work_start_d2<=`UD work_start_d1;
            end
        end


        //----set work_en----//
            reg [ 7:0] data_num;
            reg        work_en=0;
            reg        work_en_1d=0;
            always @(posedge clk)
            begin
                if(work_start_f)
                    work_en <= `UD 1'b1;
                else if(data_num == write_max_num-1'b1)
                    work_en <= `UD 1'b0;
            end
            
            always @(posedge clk)
            begin
                work_en_1d <= `UD work_en;
            end

        //----get the tx_busy's falling edge----//   
            reg            tx_busy_reg=0;
            wire           tx_busy_f;
            always @ (posedge clk) tx_busy_reg <= `UD tx_busy;
            assign tx_busy_f = (!tx_busy) && (tx_busy_reg);
        
        //----get the tx_trigger:write_pluse----//   
            reg write_pluse;
            always @ (posedge clk)
            begin
                if(work_en)
                begin
                    if(~work_en_1d || tx_busy_f) begin
                        write_pluse <= `UD 1'b1;
                    end else begin
                        write_pluse <= `UD 1'b0;
                    end
                end
                else begin
                    write_pluse <= `UD 1'b0;
                end
            end
        
            always @ (posedge clk)
            begin
                if(~work_en & tx_busy_f)
                    data_num   <= 7'h0;
                else if(write_pluse)
                    data_num   <= data_num + 8'h1;
            end
        
            always @(posedge clk)
            begin
                write_en <= `UD write_pluse;
            end

        //------------------------------------------------------------------
        // set uart_tx data area
        //------------------------------------------------------------------
        // reg read_en_d1;
        // reg read_en_d2;
        // wire read_en_f;
        // assign read_en_p = (read_en_d1) && (!read_en_d2);
        // reg read_en_p_d1;
        // wire read_en_new=read_en_p|read_en_p_d1;
        // always@(posedge clk or negedge rst_n)
        // begin
        //     if(!rst_n)begin
        //         read_en_d1<=  0;
        //         read_en_d2<=  0;
        //         read_en_p_d1<=  0;
        //     end
        //     else begin
        //         read_en_d1<=  read_en;
        //         read_en_d2<=  read_en_d1;
        //         read_en_p_d1<=  read_en_p;
        //     end
        // end

        // reg[7:0] read_data_d1;
        // always@(posedge clk or negedge rst_n)
        // begin
        //     if(!rst_n)begin
        //         read_data_d1<=  0;
        //     end
        //     else begin
        //         read_data_d1<=  read_data;
        //     end
        // end
        //----func parameter----//
            function integer     log2;
                input integer     depth ;
                for(log2=0; depth>1; log2=log2+1) begin
                    depth = depth >> 1 ;
                end
            endfunction

            reg [log2(DBUFF_DEPTH):0] wr_ptr;
            reg wr_ptr_rst;
            assign buffer_full = (wr_ptr == DBUFF_DEPTH);

        //---- buffer data ----//
        integer i;
        reg [7:0] data_buffer[DBUFF_DEPTH-1:0];
        always@(posedge clk or negedge rst_n) begin
            if(!rst_n)begin
                wr_ptr<=`UD 0;
                for( i=0;i<DBUFF_DEPTH;i=i+1)begin
                    data_buffer[i] <=`UD  8'h0;
                end
            end

            else if(work_start_f)begin
                wr_ptr<=`UD 0;
            end

            else if(read_en)begin
                for( i=0;i<DBUFF_DEPTH-1;i=i+1)begin
                    data_buffer[i] <= `UD data_buffer[i+1];
                end
                data_buffer[DBUFF_DEPTH-1] <= `UD read_data;
                wr_ptr <=`UD (wr_ptr == DBUFF_DEPTH) ? 0 : wr_ptr + 1;
            end

        end
            always @ (posedge clk or negedge rst_n)
            begin
                if(!rst_n)begin
                    wr_ptr_rst<=`UD 0;
                    write_data<=`UD 0;
                end

                else begin
                    case(data_num)
                        8'h0  ,
                        8'h1  :	write_data <=   data_buffer[11];// ASCII code is w
                        8'h2  :	write_data <=   data_buffer[10];// ASCII code is w
                        8'h3  :	write_data <=   data_buffer[9];// ASCII code is w
                        8'h4  :	write_data <=   data_buffer[8];// ASCII code is .
                        8'h5  :	write_data <=   data_buffer[7];// ASCII code is .
                        8'h6  :	write_data <=   data_buffer[6];
                        8'h7  :	write_data <=   data_buffer[5];// ASCII code is w
                        8'h8  :	write_data <=   data_buffer[4];// ASCII code is w
                        8'h9  :	write_data <=   data_buffer[3];// ASCII code is w
                        8'h10 :	write_data <=   data_buffer[2];// ASCII code is .
                        8'h11 :	write_data <=   data_buffer[1];// ASCII code is .
                        8'h12 :	write_data <=   data_buffer[0];
                        default :	write_data <=`UD read_data;
                    endcase
                end
                
            end

endmodule