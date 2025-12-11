`timescale 1ns / 1ps
//==============================================================================
// matrix_uart_display.v
// 矩阵 UART 展示模块
// 功能: 将存储的矩阵通过 UART 以 ASCII 格式发送到电脑显示
// 格式示例 (2x3 矩阵):
//   4 5 6
//   7 8 9
//==============================================================================

module matrix_uart_display (
    input wire clk,
    input wire rst_n,
    
    // 控制信号
    input wire start_display,       // 开始发送 (单周期脉冲)
    input wire [2:0] matrix_id,     // 要显示的矩阵 ID (0~3)
    input wire display_all,         // 1: 显示所有矩阵, 0: 只显示选中的矩阵
    input wire [2:0] mat_count,     // 当前存储的矩阵数量
    
    // 矩阵数据接口 (连接到 matrix_storage_unit)
    output reg [2:0] read_id,       // 读取的矩阵 ID
    output reg [4:0] read_addr,     // 读取地址 (0~24)
    input wire [3:0] read_data,     // 读取的数据
    input wire [2:0] dim_row,       // 矩阵行数
    input wire [2:0] dim_col,       // 矩阵列数
    
    // UART TX 接口
    output reg [7:0] tx_data,       // 发送的字节
    output reg tx_start,            // 发送请求
    input wire tx_busy,             // 发送忙信号
    
    // 状态输出
    output reg busy,                // 正在发送
    output reg done                 // 发送完成
);

    //==========================================================================
    // ASCII 字符定义
    //==========================================================================
    localparam ASCII_0     = 8'h30;  // '0'
    localparam ASCII_SPACE = 8'h20;  // ' '
    localparam ASCII_CR    = 8'h0D;  // '\r'
    localparam ASCII_LF    = 8'h0A;  // '\n'
    localparam ASCII_MINUS = 8'h2D;  // '-'
    localparam ASCII_M     = 8'h4D;  // 'M'
    localparam ASCII_A     = 8'h41;  // 'A'
    localparam ASCII_T     = 8'h54;  // 'T'
    localparam ASCII_R     = 8'h52;  // 'R'
    localparam ASCII_I     = 8'h49;  // 'I'
    localparam ASCII_X     = 8'h58;  // 'X'
    localparam ASCII_COLON = 8'h3A;  // ':'
    localparam ASCII_LBRK  = 8'h5B;  // '['
    localparam ASCII_RBRK  = 8'h5D;  // ']'
    localparam ASCII_x     = 8'h78;  // 'x'

    //==========================================================================
    // 状态机定义
    //==========================================================================
    localparam S_IDLE       = 4'd0;   // 空闲
    localparam S_LOAD_DIM   = 4'd1;   // 加载矩阵维度
    localparam S_SEND_HEADER= 4'd2;   // 发送标题 "MATRIX X:"
    localparam S_SEND_DIM   = 4'd3;   // 发送维度 "[RxC]"
    localparam S_SEND_NEWLINE1 = 4'd4;// 发送换行
    localparam S_LOAD_DATA  = 4'd5;   // 加载数据
    localparam S_SEND_DATA  = 4'd6;   // 发送数据
    localparam S_SEND_SPACE = 4'd7;   // 发送空格
    localparam S_SEND_CR    = 4'd8;   // 发送回车
    localparam S_SEND_LF    = 4'd9;   // 发送换行
    localparam S_NEXT_MAT   = 4'd10;  // 下一个矩阵
    localparam S_DONE       = 4'd11;  // 完成

    reg [3:0] state;
    reg [2:0] current_mat_id;         // 当前正在发送的矩阵 ID
    reg [2:0] current_row, current_col; // 当前发送位置
    reg [2:0] target_rows, target_cols; // 目标矩阵的行列数
    reg [3:0] header_idx;             // 标题字符索引
    reg [3:0] dim_idx;                // 维度字符索引
    reg [3:0] current_data;           // 当前要发送的数据
    reg       wait_tx;                // 等待发送完成标志

    //==========================================================================
    // 主状态机
    //==========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            current_mat_id <= 3'd0;
            current_row <= 3'd0;
            current_col <= 3'd0;
            target_rows <= 3'd0;
            target_cols <= 3'd0;
            header_idx <= 4'd0;
            dim_idx <= 4'd0;
            current_data <= 4'd0;
            read_id <= 3'd0;
            read_addr <= 5'd0;
            tx_data <= 8'd0;
            tx_start <= 1'b0;
            busy <= 1'b0;
            done <= 1'b0;
            wait_tx <= 1'b0;
        end else begin
            // 默认值
            tx_start <= 1'b0;
            done <= 1'b0;

            case (state)
                //--------------------------------------------------------------
                // 空闲状态: 等待启动信号
                //--------------------------------------------------------------
                S_IDLE: begin
                    if (start_display) begin
                        busy <= 1'b1;
                        if (display_all) begin
                            current_mat_id <= 3'd0;
                        end else begin
                            current_mat_id <= matrix_id;
                        end
                        state <= S_LOAD_DIM;
                    end
                end

                //--------------------------------------------------------------
                // 加载矩阵维度
                //--------------------------------------------------------------
                S_LOAD_DIM: begin
                    read_id <= current_mat_id;
                    read_addr <= 5'd0;
                    // 等待一个周期让数据稳定
                    target_rows <= dim_row;
                    target_cols <= dim_col;
                    header_idx <= 4'd0;
                    
                    // 检查矩阵是否有效
                    if (dim_row == 0 || dim_col == 0) begin
                        // 空矩阵，跳过或结束
                        if (display_all && current_mat_id < mat_count - 1) begin
                            current_mat_id <= current_mat_id + 1;
                            state <= S_LOAD_DIM;
                        end else begin
                            state <= S_DONE;
                        end
                    end else begin
                        state <= S_SEND_HEADER;
                        wait_tx <= 1'b0;
                    end
                end

                //--------------------------------------------------------------
                // 发送标题: "MATRIX X:\r\n" 
                // 简化为 "M0:" 或 "M1:" 等
                //--------------------------------------------------------------
                S_SEND_HEADER: begin
                    if (!tx_busy && !wait_tx) begin
                        case (header_idx)
                            4'd0: begin tx_data <= ASCII_M; tx_start <= 1'b1; end
                            4'd1: begin tx_data <= ASCII_0 + {5'b0, current_mat_id}; tx_start <= 1'b1; end
                            4'd2: begin tx_data <= ASCII_COLON; tx_start <= 1'b1; end
                            4'd3: begin 
                                state <= S_SEND_DIM;
                                dim_idx <= 4'd0;
                            end
                        endcase
                        if (header_idx < 4'd3) begin
                            header_idx <= header_idx + 1;
                            wait_tx <= 1'b1;
                        end
                    end
                    if (wait_tx && !tx_busy) begin
                        wait_tx <= 1'b0;
                    end
                end

                //--------------------------------------------------------------
                // 发送维度: "[RxC]\r\n"
                //--------------------------------------------------------------
                S_SEND_DIM: begin
                    if (!tx_busy && !wait_tx) begin
                        case (dim_idx)
                            4'd0: begin tx_data <= ASCII_LBRK; tx_start <= 1'b1; end
                            4'd1: begin tx_data <= ASCII_0 + {5'b0, target_rows}; tx_start <= 1'b1; end
                            4'd2: begin tx_data <= ASCII_x; tx_start <= 1'b1; end
                            4'd3: begin tx_data <= ASCII_0 + {5'b0, target_cols}; tx_start <= 1'b1; end
                            4'd4: begin tx_data <= ASCII_RBRK; tx_start <= 1'b1; end
                            4'd5: begin tx_data <= ASCII_CR; tx_start <= 1'b1; end
                            4'd6: begin tx_data <= ASCII_LF; tx_start <= 1'b1; end
                            4'd7: begin
                                state <= S_LOAD_DATA;
                                current_row <= 3'd0;
                                current_col <= 3'd0;
                            end
                        endcase
                        if (dim_idx < 4'd7) begin
                            dim_idx <= dim_idx + 1;
                            wait_tx <= 1'b1;
                        end
                    end
                    if (wait_tx && !tx_busy) begin
                        wait_tx <= 1'b0;
                    end
                end

                //--------------------------------------------------------------
                // 加载数据: 从存储单元读取当前元素
                //--------------------------------------------------------------
                S_LOAD_DATA: begin
                    read_id <= current_mat_id;
                    read_addr <= current_row * 5 + current_col;
                    // 等待一个周期
                    current_data <= read_data;
                    state <= S_SEND_DATA;
                    wait_tx <= 1'b0;
                end

                //--------------------------------------------------------------
                // 发送数据: 将 0~9 转换为 ASCII '0'~'9'
                //--------------------------------------------------------------
                S_SEND_DATA: begin
                    if (!tx_busy && !wait_tx) begin
                        tx_data <= ASCII_0 + {4'b0, current_data};
                        tx_start <= 1'b1;
                        wait_tx <= 1'b1;
                    end
                    if (wait_tx && !tx_busy) begin
                        wait_tx <= 1'b0;
                        // 判断下一个动作
                        if (current_col == target_cols - 1) begin
                            // 行末，发送换行
                            state <= S_SEND_CR;
                        end else begin
                            // 发送空格
                            state <= S_SEND_SPACE;
                        end
                    end
                end

                //--------------------------------------------------------------
                // 发送空格
                //--------------------------------------------------------------
                S_SEND_SPACE: begin
                    if (!tx_busy && !wait_tx) begin
                        tx_data <= ASCII_SPACE;
                        tx_start <= 1'b1;
                        wait_tx <= 1'b1;
                    end
                    if (wait_tx && !tx_busy) begin
                        wait_tx <= 1'b0;
                        current_col <= current_col + 1;
                        state <= S_LOAD_DATA;
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
                        // 判断是否还有更多行
                        if (current_row == target_rows - 1) begin
                            // 当前矩阵发送完成
                            state <= S_NEXT_MAT;
                        end else begin
                            current_row <= current_row + 1;
                            current_col <= 3'd0;
                            state <= S_LOAD_DATA;
                        end
                    end
                end

                //--------------------------------------------------------------
                // 下一个矩阵
                //--------------------------------------------------------------
                S_NEXT_MAT: begin
                    if (display_all && current_mat_id < mat_count - 1) begin
                        current_mat_id <= current_mat_id + 1;
                        state <= S_LOAD_DIM;
                    end else begin
                        state <= S_DONE;
                    end
                end

                //--------------------------------------------------------------
                // 完成
                //--------------------------------------------------------------
                S_DONE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
