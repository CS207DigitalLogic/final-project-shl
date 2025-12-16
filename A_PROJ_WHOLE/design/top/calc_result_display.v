`timescale 1ns / 1ps
//==============================================================================
// calc_result_display.v
// 计算结果 UART 展示模块
// 功能: 将矩阵计算结果通过 UART 以 ASCII 格式发送到电脑显示
// 格式示例 (2x3 结果矩阵):
//   Result:[2x3]
//   10 15 20
//   25 30 35
//==============================================================================

module calc_result_display #(
    parameter MAX_DIM = 5,
    parameter RESULT_WIDTH = 16
)(
    input wire clk,
    input wire rst_n,
    
    // 控制信号
    input wire start_display,           // 开始发送 (单周期脉冲)
    input wire [2:0] result_rows,       // 结果矩阵行数
    input wire [2:0] result_cols,       // 结果矩阵列数
    input wire [2:0] op_type,           // 操作类型: 000=转置, 001=加法, 010=标量乘, 011=矩阵乘
    
    // 矩阵数据接口 (直接连接到计算模块的结果)
    output reg [4:0] result_read_addr,  // 读取地址 (0~24)
    input wire [RESULT_WIDTH-1:0] read_data,  // 读取的数据
    
    // UART TX 接口
    output reg [7:0] tx_data,           // 发送的字节
    output reg tx_start,                // 发送请求
    input wire tx_busy,                 // 发送忙信号
    
    // 状态输出
    output reg busy,                    // 正在发送
    output reg done                     // 发送完成
);

    //==========================================================================
    // ASCII 字符定义
    //==========================================================================
    localparam ASCII_0     = 8'h30;  // '0'
    localparam ASCII_SPACE = 8'h20;  // ' '
    localparam ASCII_CR    = 8'h0D;  // '\r'
    localparam ASCII_LF    = 8'h0A;  // '\n'
    localparam ASCII_R     = 8'h52;  // 'R'
    localparam ASCII_E     = 8'h45;  // 'E'
    localparam ASCII_S     = 8'h53;  // 'S'
    localparam ASCII_U     = 8'h55;  // 'U'
    localparam ASCII_L     = 8'h4C;  // 'L'
    localparam ASCII_T     = 8'h54;  // 'T'
    localparam ASCII_COLON = 8'h3A;  // ':'
    localparam ASCII_LBRK  = 8'h5B;  // '['
    localparam ASCII_RBRK  = 8'h5D;  // ']'
    localparam ASCII_X     = 8'h78;  // 'x'

    //==========================================================================
    // 状态定义
    //==========================================================================
    localparam S_IDLE        = 4'd0;
    localparam S_SEND_TITLE  = 4'd1;  // 发送 "Result:"
    localparam S_SEND_DIM    = 4'd2;  // 发送维度 "[rows x cols]"
    localparam S_SEND_LF     = 4'd3;  // 发送换行
    localparam S_READ_WAIT   = 4'd4;  // 等待读取数据
    localparam S_SEND_DATA   = 4'd5;  // 发送数据
    localparam S_SEND_SPACE  = 4'd6;  // 发送空格
    localparam S_SEND_NEWLINE = 4'd7; // 发送新行
    localparam S_DONE        = 4'd8;

    reg [3:0] state, state_next;
    reg [2:0] row_idx, col_idx;       // 当前行、列索引
    reg [2:0] title_idx;              // 标题发送位置
    reg [RESULT_WIDTH-1:0] current_data;
    reg [4:0] data_digit_count;       // 数据的位数
    
    //==========================================================================
    // 状态机
    //==========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            busy <= 1'b0;
            done <= 1'b0;
            tx_start <= 1'b0;
            result_read_addr <= 5'd0;
            row_idx <= 3'd0;
            col_idx <= 3'd0;
            title_idx <= 3'd0;
            current_data <= 0;
            data_digit_count <= 5'd0;
        end else begin
            done <= 1'b0;
            tx_start <= 1'b0;
            state <= state_next;
            
            case (state)
                //--------------------------------------------------------------
                // 空闲状态
                //--------------------------------------------------------------
                S_IDLE: begin
                    busy <= 1'b0;
                    if (start_display) begin
                        busy <= 1'b1;
                        row_idx <= 3'd0;
                        col_idx <= 3'd0;
                        title_idx <= 3'd0;
                        state <= S_SEND_TITLE;
                    end
                end
                
                //--------------------------------------------------------------
                // 发送标题 "Result:"
                //--------------------------------------------------------------
                S_SEND_TITLE: begin
                    tx_start <= 1'b1;
                    case (title_idx)
                        3'd0: tx_data <= ASCII_R;
                        3'd1: tx_data <= ASCII_E;
                        3'd2: tx_data <= ASCII_S;
                        3'd3: tx_data <= ASCII_U;
                        3'd4: tx_data <= ASCII_L;
                        3'd5: tx_data <= ASCII_T;
                        3'd6: tx_data <= ASCII_COLON;
                        default: tx_data <= ASCII_SPACE;
                    endcase
                    
                    if (!tx_busy) begin
                        if (title_idx == 3'd6) begin
                            title_idx <= 3'd0;
                            state <= S_SEND_DIM;
                        end else begin
                            title_idx <= title_idx + 1'b1;
                        end
                    end
                end
                
                //--------------------------------------------------------------
                // 发送维度 "[rows x cols]"
                //--------------------------------------------------------------
                S_SEND_DIM: begin
                    tx_start <= 1'b1;
                    // 简化处理：直接发送数字表示
                    if (title_idx == 3'd0) begin
                        tx_data <= ASCII_LBRK;  // '['
                    end else if (title_idx == 3'd1) begin
                        tx_data <= ASCII_0 + result_rows;  // 行数
                    end else if (title_idx == 3'd2) begin
                        tx_data <= ASCII_X;  // 'x'
                    end else if (title_idx == 3'd3) begin
                        tx_data <= ASCII_0 + result_cols;  // 列数
                    end else if (title_idx == 3'd4) begin
                        tx_data <= ASCII_RBRK;  // ']'
                    end else begin
                        tx_data <= ASCII_SPACE;
                    end
                    
                    if (!tx_busy) begin
                        if (title_idx == 3'd4) begin
                            title_idx <= 3'd0;
                            state <= S_SEND_LF;
                        end else begin
                            title_idx <= title_idx + 1'b1;
                        end
                    end
                end
                
                //--------------------------------------------------------------
                // 发送换行
                //--------------------------------------------------------------
                S_SEND_LF: begin
                    tx_start <= 1'b1;
                    tx_data <= ASCII_LF;
                    if (!tx_busy) begin
                        result_read_addr <= row_idx * 5 + col_idx;
                        state <= S_READ_WAIT;
                    end
                end
                
                //--------------------------------------------------------------
                // 等待读取数据
                //--------------------------------------------------------------
                S_READ_WAIT: begin
                    current_data <= read_data;
                    // 计算数据的位数
                    if (read_data >= 16'd100) data_digit_count <= 5'd3;
                    else if (read_data >= 16'd10) data_digit_count <= 5'd2;
                    else data_digit_count <= 5'd1;
                    
                    state <= S_SEND_DATA;
                end
                
                //--------------------------------------------------------------
                // 发送数据
                //--------------------------------------------------------------
                S_SEND_DATA: begin
                    tx_start <= 1'b1;
                    
                    // 发送数据的各位数字
                    if (data_digit_count == 5'd3) begin
                        tx_data <= ASCII_0 + (current_data / 100);
                    end else if (data_digit_count == 5'd2) begin
                        if (current_data >= 16'd100) begin
                            tx_data <= ASCII_0 + ((current_data / 10) % 10);
                        end else begin
                            tx_data <= ASCII_0 + (current_data / 10);
                        end
                    end else begin
                        tx_data <= ASCII_0 + (current_data % 10);
                    end
                    
                    if (!tx_busy) begin
                        if (data_digit_count > 5'd1) begin
                            data_digit_count <= data_digit_count - 1'b1;
                        end else begin
                            state <= S_SEND_SPACE;
                        end
                    end
                end
                
                //--------------------------------------------------------------
                // 发送空格或换行
                //--------------------------------------------------------------
                S_SEND_SPACE: begin
                    tx_start <= 1'b1;
                    
                    if (col_idx + 1 < result_cols) begin
                        // 行内：发送空格
                        tx_data <= ASCII_SPACE;
                        if (!tx_busy) begin
                            col_idx <= col_idx + 1'b1;
                            result_read_addr <= row_idx * 5 + (col_idx + 1);
                            state <= S_READ_WAIT;
                        end
                    end else begin
                        // 行末：发送换行
                        tx_data <= ASCII_LF;
                        if (!tx_busy) begin
                            col_idx <= 3'd0;
                            if (row_idx + 1 < result_rows) begin
                                row_idx <= row_idx + 1'b1;
                                result_read_addr <= (row_idx + 1) * 5;
                                state <= S_READ_WAIT;
                            end else begin
                                state <= S_DONE;
                            end
                        end
                    end
                end
                
                //--------------------------------------------------------------
                // 完成状态
                //--------------------------------------------------------------
                S_DONE: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
