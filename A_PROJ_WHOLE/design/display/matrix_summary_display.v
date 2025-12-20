`timescale 1ns / 1ps
//==============================================================================
// matrix_summary_display.v
// 矩阵摘要展示模块
// 功能: 显示存储矩阵的摘要信息
// 输出格式: 总数 m*n*x m*n*x ...
// 例如: 3 2*2*1 4*5*2 表示3个矩阵，1个2x2，2个4x5
//==============================================================================

module matrix_summary_display #(
    parameter MAX_MATRICES = 7,
    parameter PTR_WIDTH = 3
)(
    input wire clk,
    input wire rst_n,
    
    // 控制信号
    input wire start_display,       // 开始发送 (单周期脉冲)
    input wire [PTR_WIDTH:0] mat_count, // 当前存储的矩阵数量
    
    // 矩阵维度读取接口 (需要遍历所有矩阵)
    output reg [PTR_WIDTH-1:0] read_id, // 读取的矩阵 ID
    input wire [2:0] dim_row,           // 矩阵行数
    input wire [2:0] dim_col,           // 矩阵列数
    
    // UART TX 接口
    output reg [7:0] tx_data,
    output reg tx_start,
    input wire tx_busy,
    
    // 状态输出
    output reg busy,
    output reg done
);

    //==========================================================================
    // ASCII 字符定义
    //==========================================================================
    localparam ASCII_0     = 8'h30;  // '0'
    localparam ASCII_SPACE = 8'h20;  // ' '
    localparam ASCII_CR    = 8'h0D;  // '\r'
    localparam ASCII_LF    = 8'h0A;  // '\n'
    localparam ASCII_STAR  = 8'h2A;  // '*'

    //==========================================================================
    // 状态机定义
    //==========================================================================
    localparam S_IDLE        = 4'd0;
    localparam S_SCAN_START  = 4'd1;   // 开始扫描
    localparam S_SCAN_WAIT   = 4'd2;   // 等待读取稳定
    localparam S_SCAN_READ   = 4'd3;   // 读取并统计
    localparam S_SCAN_NEXT   = 4'd4;   // 下一个矩阵
    localparam S_SEND_TOTAL  = 4'd5;   // 发送总数
    localparam S_SEND_SPACE1 = 4'd6;   // 发送空格
    localparam S_FIND_SPEC   = 4'd7;   // 查找下一个规格
    localparam S_SEND_SPEC   = 4'd8;   // 发送规格 m*n*x
    localparam S_SEND_CR     = 4'd9;   // 发送回车
    localparam S_SEND_LF     = 4'd10;  // 发送换行
    localparam S_DONE        = 4'd11;

    reg [3:0] state;
    reg wait_tx;

    //==========================================================================
    // 规格统计存储
    // 用一个简单的方法：记录每种规格(row, col)出现的次数
    // 最多 5x5 = 25 种规格
    //==========================================================================
    reg [2:0] spec_count [0:24];  // spec_count[row*5+col-6] = 该规格的数量
                                  // 索引 = (row-1)*5 + (col-1), row/col从1开始
    
    // 扫描相关
    reg [PTR_WIDTH-1:0] scan_idx;
    reg [2:0] cached_row, cached_col;
    
    // 发送相关
    reg [4:0] spec_idx;           // 当前检查的规格索引 (0~24)
    reg [2:0] send_step;          // 发送步骤 (m, *, n, *, x)
    reg [2:0] current_spec_row;
    reg [2:0] current_spec_col;
    reg [2:0] current_spec_cnt;
    reg       first_spec;         // 是否是第一个规格（不需要前置空格）

    integer i;

    //==========================================================================
    // 主状态机
    //==========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            read_id <= 0;
            tx_data <= 8'd0;
            tx_start <= 1'b0;
            busy <= 1'b0;
            done <= 1'b0;
            wait_tx <= 1'b0;
            scan_idx <= 0;
            spec_idx <= 0;
            send_step <= 0;
            cached_row <= 0;
            cached_col <= 0;
            current_spec_row <= 0;
            current_spec_col <= 0;
            current_spec_cnt <= 0;
            first_spec <= 1'b1;
            for (i = 0; i < 25; i = i + 1) begin
                spec_count[i] <= 0;
            end
        end else begin
            // 默认值
            tx_start <= 1'b0;
            done <= 1'b0;

            case (state)
                //--------------------------------------------------------------
                // 空闲状态
                //--------------------------------------------------------------
                S_IDLE: begin
                    busy <= 1'b0;
                    if (start_display) begin
                        busy <= 1'b1;
                        scan_idx <= 0;
                        spec_idx <= 0;
                        first_spec <= 1'b1;
                        // 清空统计
                        for (i = 0; i < 25; i = i + 1) begin
                            spec_count[i] <= 0;
                        end
                        
                        if (mat_count == 0) begin
                            // 没有矩阵，直接发送 "0\r\n"
                            state <= S_SEND_TOTAL;
                        end else begin
                            state <= S_SCAN_START;
                        end
                    end
                end

                //--------------------------------------------------------------
                // 开始扫描：设置读取ID
                //--------------------------------------------------------------
                S_SCAN_START: begin
                    read_id <= scan_idx;
                    state <= S_SCAN_WAIT;
                end

                //--------------------------------------------------------------
                // 等待读取稳定
                //--------------------------------------------------------------
                S_SCAN_WAIT: begin
                    state <= S_SCAN_READ;
                end

                //--------------------------------------------------------------
                // 读取并统计
                //--------------------------------------------------------------
                S_SCAN_READ: begin
                    cached_row <= dim_row;
                    cached_col <= dim_col;
                    
                    // 只统计有效矩阵 (维度不为0)
                    if (dim_row != 0 && dim_col != 0) begin
                        // 索引 = (row-1)*5 + (col-1)
                        spec_count[(dim_row-1)*5 + (dim_col-1)] <= 
                            spec_count[(dim_row-1)*5 + (dim_col-1)] + 1;
                    end
                    
                    state <= S_SCAN_NEXT;
                end

                //--------------------------------------------------------------
                // 下一个矩阵
                //--------------------------------------------------------------
                S_SCAN_NEXT: begin
                    if (scan_idx + 1 < mat_count) begin
                        scan_idx <= scan_idx + 1;
                        state <= S_SCAN_START;
                    end else begin
                        // 扫描完成，开始发送
                        state <= S_SEND_TOTAL;
                        wait_tx <= 1'b0;
                    end
                end

                //--------------------------------------------------------------
                // 发送总数
                //--------------------------------------------------------------
                S_SEND_TOTAL: begin
                    if (!tx_busy && !wait_tx) begin
                        tx_data <= ASCII_0 + mat_count[3:0];
                        tx_start <= 1'b1;
                        wait_tx <= 1'b1;
                    end
                    if (wait_tx && !tx_busy) begin
                        wait_tx <= 1'b0;
                        spec_idx <= 0;
                        state <= S_FIND_SPEC;
                    end
                end

                //--------------------------------------------------------------
                // 查找下一个有效规格
                //--------------------------------------------------------------
                S_FIND_SPEC: begin
                    if (spec_idx < 25) begin
                        if (spec_count[spec_idx] > 0) begin
                            // 找到一个有效规格
                            current_spec_row <= (spec_idx / 5) + 1;
                            current_spec_col <= (spec_idx % 5) + 1;
                            current_spec_cnt <= spec_count[spec_idx];
                            send_step <= 0;
                            state <= S_SEND_SPACE1;
                        end else begin
                            spec_idx <= spec_idx + 1;
                            // 保持在 S_FIND_SPEC
                        end
                    end else begin
                        // 没有更多规格了
                        state <= S_SEND_CR;
                    end
                end

                //--------------------------------------------------------------
                // 发送空格 (规格之间的分隔)
                //--------------------------------------------------------------
                S_SEND_SPACE1: begin
                    if (!tx_busy && !wait_tx) begin
                        tx_data <= ASCII_SPACE;
                        tx_start <= 1'b1;
                        wait_tx <= 1'b1;
                    end
                    if (wait_tx && !tx_busy) begin
                        wait_tx <= 1'b0;
                        state <= S_SEND_SPEC;
                        send_step <= 0;
                    end
                end

                //--------------------------------------------------------------
                // 发送规格: m*n*x
                //--------------------------------------------------------------
                S_SEND_SPEC: begin
                    if (!tx_busy && !wait_tx) begin
                        case (send_step)
                            3'd0: begin  // 发送 m (行数)
                                tx_data <= ASCII_0 + {5'b0, current_spec_row};
                                tx_start <= 1'b1;
                                wait_tx <= 1'b1;
                                send_step <= 3'd1;
                            end
                            3'd1: begin  // 发送 *
                                tx_data <= ASCII_STAR;
                                tx_start <= 1'b1;
                                wait_tx <= 1'b1;
                                send_step <= 3'd2;
                            end
                            3'd2: begin  // 发送 n (列数)
                                tx_data <= ASCII_0 + {5'b0, current_spec_col};
                                tx_start <= 1'b1;
                                wait_tx <= 1'b1;
                                send_step <= 3'd3;
                            end
                            3'd3: begin  // 发送 *
                                tx_data <= ASCII_STAR;
                                tx_start <= 1'b1;
                                wait_tx <= 1'b1;
                                send_step <= 3'd4;
                            end
                            3'd4: begin  // 发送 x (数量)
                                tx_data <= ASCII_0 + {5'b0, current_spec_cnt};
                                tx_start <= 1'b1;
                                wait_tx <= 1'b1;
                                send_step <= 3'd5;
                            end
                            3'd5: begin  // 完成该规格，查找下一个
                                spec_idx <= spec_idx + 1;
                                first_spec <= 1'b0;
                                state <= S_FIND_SPEC;
                            end
                        endcase
                    end
                    if (wait_tx && !tx_busy) begin
                        wait_tx <= 1'b0;
                    end
                end

                //--------------------------------------------------------------
                // 发送回车
                //--------------------------------------------------------------
                S_SEND_CR: begin
                    if (!tx_busy && !wait_tx) begin
                        tx_data <= ASCII_CR;
                        tx_start <= 1'b1;
                        wait_tx <= 1'b1;
                    end
                    if (wait_tx && !tx_busy) begin
                        wait_tx <= 1'b0;
                        state <= S_SEND_LF;
                    end
                end

                //--------------------------------------------------------------
                // 发送换行
                //--------------------------------------------------------------
                S_SEND_LF: begin
                    if (!tx_busy && !wait_tx) begin
                        tx_data <= ASCII_LF;
                        tx_start <= 1'b1;
                        wait_tx <= 1'b1;
                    end
                    if (wait_tx && !tx_busy) begin
                        wait_tx <= 1'b0;
                        state <= S_DONE;
                    end
                end

                //--------------------------------------------------------------
                // 完成
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
