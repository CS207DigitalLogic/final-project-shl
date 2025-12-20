`timescale 1ns / 1ps
//==============================================================================
// operand_display.v
// 运算数展示模块
// 功能：将选中的运算数通过UART以ASCII格式发送到电脑显示
// 显示顺序：
//   - 转置: 显示矩阵A
//   - 加法: 显示矩阵A，然后显示矩阵B
//   - 标量乘: 显示矩阵A，然后显示标量值
//   - 矩阵乘: 显示矩阵A，然后显示矩阵B
// 格式示例:
//   === Operand A ===
//   M0:[2x3]
//   4 5 6
//   7 8 9
//   === Operand B ===
//   M1:[2x3]
//   1 2 3
//   4 5 6
//   或者（标量乘）:
//   === Scalar ===
//   x = 5
//==============================================================================

module operand_display #(
    parameter PTR_WIDTH = 4
)(
    input wire clk,
    input wire rst_n,
    
    //--------------------------------------------------------------------------
    // 控制接口
    //--------------------------------------------------------------------------
    input wire        start_display,    // 开始发送 (单周期脉冲)
    input wire [2:0]  op_type,          // 运算类型: 000=转置, 001=加法, 010=标量乘, 011=矩阵乘
    
    // 运算数信息
    input wire [PTR_WIDTH-1:0] operand_A_id,  // 运算数A的矩阵ID
    input wire [PTR_WIDTH-1:0] operand_B_id,  // 运算数B的矩阵ID
    input wire [3:0]           scalar_val,    // 标量值 (标量乘用)
    
    //--------------------------------------------------------------------------
    // 矩阵数据接口 (连接到 matrix_storage_unit)
    //--------------------------------------------------------------------------
    output reg [PTR_WIDTH-1:0] read_id,     // 读取的矩阵 ID
    output reg [4:0]           read_addr,   // 读取地址 (0~24)
    input wire [3:0]           read_data,   // 读取的数据
    input wire [2:0]           dim_row,     // 矩阵行数
    input wire [2:0]           dim_col,     // 矩阵列数
    
    //--------------------------------------------------------------------------
    // UART TX 接口
    //--------------------------------------------------------------------------
    output reg [7:0] tx_data,       // 发送的字节
    output reg       tx_start,      // 发送请求
    input wire       tx_busy,       // 发送忙信号
    
    //--------------------------------------------------------------------------
    // 状态输出
    //--------------------------------------------------------------------------
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
    localparam ASCII_M     = 8'h4D;  // 'M'
    localparam ASCII_COLON = 8'h3A;  // ':'
    localparam ASCII_LBRK  = 8'h5B;  // '['
    localparam ASCII_RBRK  = 8'h5D;  // ']'
    localparam ASCII_x     = 8'h78;  // 'x'
    localparam ASCII_EQ    = 8'h3D;  // '='
    localparam ASCII_A     = 8'h41;  // 'A'
    localparam ASCII_B     = 8'h42;  // 'B'
    localparam ASCII_S     = 8'h53;  // 'S'
    localparam ASCII_c     = 8'h63;  // 'c'
    localparam ASCII_a     = 8'h61;  // 'a'
    localparam ASCII_l     = 8'h6C;  // 'l'
    localparam ASCII_r     = 8'h72;  // 'r'
    localparam ASCII_O     = 8'h4F;  // 'O'
    localparam ASCII_p     = 8'h70;  // 'p'
    localparam ASCII_e     = 8'h65;  // 'e'
    localparam ASCII_n     = 8'h6E;  // 'n'
    localparam ASCII_d     = 8'h64;  // 'd'

    //==========================================================================
    // 运算类型定义
    //==========================================================================
    localparam OP_TRANSPOSE = 3'b000;
    localparam OP_ADD       = 3'b001;
    localparam OP_SCALAR    = 3'b010;
    localparam OP_MULTIPLY  = 3'b011;

    //==========================================================================
    // 状态机定义
    //==========================================================================
    localparam S_IDLE        = 5'd0;
    localparam S_INIT        = 5'd1;
    localparam S_WAIT_STABLE = 5'd2;   // 新增：等待ID稳定
    
    // 发送 "OpA:" 标题
    localparam S_SEND_OP_A   = 5'd3;
    localparam S_SET_ID_A    = 5'd4;
    localparam S_LOAD_DIM_A  = 5'd5;
    localparam S_SEND_HDR_A  = 5'd6;   // 发送 "MX:[RxC]\r\n"
    localparam S_SET_ADDR_A  = 5'd7;
    localparam S_LOAD_DATA_A = 5'd8;
    localparam S_SEND_DATA_A = 5'd9;
    localparam S_SEND_SP_A   = 5'd10;  // 发送空格
    localparam S_SEND_CR_A   = 5'd11;  // 发送回车
    localparam S_SEND_LF_A   = 5'd12;  // 发送换行
    
    // 发送 "OpB:" 或 "Scalar:" 标题
    localparam S_SEND_OP_B   = 5'd13;
    localparam S_SET_ID_B    = 5'd14;
    localparam S_LOAD_DIM_B  = 5'd15;
    localparam S_SEND_HDR_B  = 5'd16;  // 发送 "MX:[RxC]\r\n"
    localparam S_SET_ADDR_B  = 5'd17;
    localparam S_LOAD_DATA_B = 5'd18;
    localparam S_SEND_DATA_B = 5'd19;
    localparam S_SEND_SP_B   = 5'd20;
    localparam S_SEND_CR_B   = 5'd21;
    localparam S_SEND_LF_B   = 5'd22;
    
    // 发送标量值
    localparam S_SEND_SCALAR = 5'd23;
    
    localparam S_DONE        = 5'd24;

    reg [4:0] state;
    
    //==========================================================================
    // 内部变量
    //==========================================================================
    reg [2:0] saved_op_type;
    reg [PTR_WIDTH-1:0] saved_A_id, saved_B_id;
    reg [3:0] saved_scalar;
    
    reg [2:0] current_row, current_col;
    reg [2:0] target_rows, target_cols;
    reg [4:0] header_idx;
    reg [3:0] current_data;
    reg       wait_tx;
    reg [1:0] wait_cycles;  // 新增：等待周期计数器
    
    // 需要显示B吗？
    wire needs_B = (saved_op_type == OP_ADD) || (saved_op_type == OP_MULTIPLY);
    // 需要显示标量吗？
    wire needs_scalar = (saved_op_type == OP_SCALAR);

    //==========================================================================
    // 主状态机
    //==========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            busy <= 1'b0;
            done <= 1'b0;
            tx_data <= 8'd0;
            tx_start <= 1'b0;
            read_id <= 0;
            read_addr <= 5'd0;
            saved_op_type <= 3'd0;
            saved_A_id <= 0;
            saved_B_id <= 0;
            saved_scalar <= 4'd0;
            current_row <= 3'd0;
            current_col <= 3'd0;
            target_rows <= 3'd0;
            target_cols <= 3'd0;
            header_idx <= 5'd0;
            current_data <= 4'd0;
            wait_tx <= 1'b0;
            wait_cycles <= 2'd0;
        end else begin
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
                        saved_op_type <= op_type;
                        saved_A_id <= operand_A_id;
                        saved_B_id <= operand_B_id;
                        saved_scalar <= scalar_val;
                        state <= S_INIT;
                    end
                end
                
                //--------------------------------------------------------------
                // 初始化
                //--------------------------------------------------------------
                S_INIT: begin
                    header_idx <= 5'd0;
                    wait_tx <= 1'b0;
                    wait_cycles <= 2'd0;
                    state <= S_WAIT_STABLE;
                end
                
                //--------------------------------------------------------------
                // 等待ID稳定（新增状态）
                //--------------------------------------------------------------
                S_WAIT_STABLE: begin
                    if (wait_cycles < 2'd2) begin
                        wait_cycles <= wait_cycles + 1'b1;
                    end else begin
                        wait_cycles <= 2'd0;
                        state <= S_SEND_OP_A;
                    end
                end
                
                //--------------------------------------------------------------
                // 发送 "OpA:\r\n" (Operand A 标题)
                // 格式: O p A : \r \n
                //--------------------------------------------------------------
                S_SEND_OP_A: begin
                    if (!tx_busy && !wait_tx) begin
                        case (header_idx)
                            5'd0: begin tx_data <= ASCII_O; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd1; end
                            5'd1: begin tx_data <= ASCII_p; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd2; end
                            5'd2: begin tx_data <= ASCII_A; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd3; end
                            5'd3: begin tx_data <= ASCII_COLON; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd4; end
                            5'd4: begin tx_data <= ASCII_CR; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd5; end
                            5'd5: begin tx_data <= ASCII_LF; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd6; end
                            5'd6: begin
                                header_idx <= 5'd0;
                                state <= S_SET_ID_A;
                            end
                            default: header_idx <= 5'd0;
                        endcase
                    end
                    if (wait_tx && !tx_busy) wait_tx <= 1'b0;
                end
                
                //--------------------------------------------------------------
                // 设置读取ID（矩阵A）
                //--------------------------------------------------------------
                S_SET_ID_A: begin
                    read_id <= saved_A_id;
                    read_addr <= 5'd0;
                    wait_cycles <= 2'd0;
                    state <= S_LOAD_DIM_A;
                end
                
                //--------------------------------------------------------------
                // 加载矩阵A维度（增加等待周期）
                //--------------------------------------------------------------
                S_LOAD_DIM_A: begin
                    if (wait_cycles < 2'd2) begin
                        wait_cycles <= wait_cycles + 1'b1;
                    end else begin
                        target_rows <= dim_row;
                        target_cols <= dim_col;
                        header_idx <= 5'd0;
                        wait_cycles <= 2'd0;
                        state <= S_SEND_HDR_A;
                    end
                end
                
                //--------------------------------------------------------------
                // 发送矩阵A头部: "MX:[RxC]\r\n"
                //--------------------------------------------------------------
                S_SEND_HDR_A: begin
                    if (!tx_busy && !wait_tx) begin
                        case (header_idx)
                            5'd0: begin tx_data <= ASCII_M; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd1; end
                            5'd1: begin tx_data <= ASCII_0 + {4'b0, saved_A_id}; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd2; end
                            5'd2: begin tx_data <= ASCII_COLON; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd3; end
                            5'd3: begin tx_data <= ASCII_LBRK; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd4; end
                            5'd4: begin tx_data <= ASCII_0 + {5'b0, target_rows}; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd5; end
                            5'd5: begin tx_data <= ASCII_x; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd6; end
                            5'd6: begin tx_data <= ASCII_0 + {5'b0, target_cols}; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd7; end
                            5'd7: begin tx_data <= ASCII_RBRK; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd8; end
                            5'd8: begin tx_data <= ASCII_CR; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd9; end
                            5'd9: begin tx_data <= ASCII_LF; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd10; end
                            5'd10: begin
                                current_row <= 3'd0;
                                current_col <= 3'd0;
                                state <= S_SET_ADDR_A;
                            end
                            default: header_idx <= 5'd0;
                        endcase
                    end
                    if (wait_tx && !tx_busy) wait_tx <= 1'b0;
                end
                
                //--------------------------------------------------------------
                // 设置读取地址（矩阵A）
                //--------------------------------------------------------------
                S_SET_ADDR_A: begin
                    read_id <= saved_A_id;
                    read_addr <= current_row * 5 + current_col;
                    wait_cycles <= 2'd0;
                    state <= S_LOAD_DATA_A;
                end
                
                //--------------------------------------------------------------
                // 加载数据（矩阵A）- 增加等待周期
                //--------------------------------------------------------------
                S_LOAD_DATA_A: begin
                    if (wait_cycles < 2'd1) begin
                        wait_cycles <= wait_cycles + 1'b1;
                    end else begin
                        current_data <= read_data;
                        wait_cycles <= 2'd0;
                        state <= S_SEND_DATA_A;
                        wait_tx <= 1'b0;
                    end
                end
                
                //--------------------------------------------------------------
                // 发送数据（矩阵A）
                //--------------------------------------------------------------
                S_SEND_DATA_A: begin
                    if (!tx_busy && !wait_tx) begin
                        tx_data <= ASCII_0 + {4'b0, current_data};
                        tx_start <= 1'b1;
                        wait_tx <= 1'b1;
                    end
                    if (wait_tx && !tx_busy) begin
                        wait_tx <= 1'b0;
                        if (current_col == target_cols - 1) begin
                            state <= S_SEND_CR_A;
                        end else begin
                            state <= S_SEND_SP_A;
                        end
                    end
                end
                
                //--------------------------------------------------------------
                // 发送空格（矩阵A）
                //--------------------------------------------------------------
                S_SEND_SP_A: begin
                    if (!tx_busy && !wait_tx) begin
                        tx_data <= ASCII_SPACE;
                        tx_start <= 1'b1;
                        wait_tx <= 1'b1;
                    end
                    if (wait_tx && !tx_busy) begin
                        wait_tx <= 1'b0;
                        current_col <= current_col + 1;
                        state <= S_SET_ADDR_A;
                    end
                end
                
                //--------------------------------------------------------------
                // 发送回车（矩阵A）
                //--------------------------------------------------------------
                S_SEND_CR_A: begin
                    if (!tx_busy && !wait_tx) begin
                        tx_data <= ASCII_CR;
                        tx_start <= 1'b1;
                        wait_tx <= 1'b1;
                    end
                    if (wait_tx && !tx_busy) begin
                        wait_tx <= 1'b0;
                        state <= S_SEND_LF_A;
                    end
                end
                
                //--------------------------------------------------------------
                // 发送换行（矩阵A）
                //--------------------------------------------------------------
                S_SEND_LF_A: begin
                    if (!tx_busy && !wait_tx) begin
                        tx_data <= ASCII_LF;
                        tx_start <= 1'b1;
                        wait_tx <= 1'b1;
                    end
                    if (wait_tx && !tx_busy) begin
                        wait_tx <= 1'b0;
                        if (current_row == target_rows - 1) begin
                            // 矩阵A发送完毕
                            if (needs_B) begin
                                header_idx <= 5'd0;
                                state <= S_SEND_OP_B;
                            end else if (needs_scalar) begin
                                header_idx <= 5'd0;
                                state <= S_SEND_SCALAR;
                            end else begin
                                state <= S_DONE;
                            end
                        end else begin
                            current_row <= current_row + 1;
                            current_col <= 3'd0;
                            state <= S_SET_ADDR_A;
                        end
                    end
                end
                
                //--------------------------------------------------------------
                // 发送 "OpB:\r\n" (Operand B 标题)
                //--------------------------------------------------------------
                S_SEND_OP_B: begin
                    if (!tx_busy && !wait_tx) begin
                        case (header_idx)
                            5'd0: begin tx_data <= ASCII_O; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd1; end
                            5'd1: begin tx_data <= ASCII_p; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd2; end
                            5'd2: begin tx_data <= ASCII_B; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd3; end
                            5'd3: begin tx_data <= ASCII_COLON; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd4; end
                            5'd4: begin tx_data <= ASCII_CR; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd5; end
                            5'd5: begin tx_data <= ASCII_LF; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd6; end
                            5'd6: begin
                                header_idx <= 5'd0;
                                state <= S_SET_ID_B;
                            end
                            default: header_idx <= 5'd0;
                        endcase
                    end
                    if (wait_tx && !tx_busy) wait_tx <= 1'b0;
                end
                
                //--------------------------------------------------------------
                // 设置读取ID（矩阵B）
                //--------------------------------------------------------------
                S_SET_ID_B: begin
                    read_id <= saved_B_id;
                    read_addr <= 5'd0;
                    wait_cycles <= 2'd0;
                    state <= S_LOAD_DIM_B;
                end
                
                //--------------------------------------------------------------
                // 加载矩阵B维度（增加等待周期）
                //--------------------------------------------------------------
                S_LOAD_DIM_B: begin
                    if (wait_cycles < 2'd2) begin
                        wait_cycles <= wait_cycles + 1'b1;
                    end else begin
                        target_rows <= dim_row;
                        target_cols <= dim_col;
                        header_idx <= 5'd0;
                        wait_cycles <= 2'd0;
                        state <= S_SEND_HDR_B;
                    end
                end
                
                //--------------------------------------------------------------
                // 发送矩阵B头部: "MX:[RxC]\r\n"
                //--------------------------------------------------------------
                S_SEND_HDR_B: begin
                    if (!tx_busy && !wait_tx) begin
                        case (header_idx)
                            5'd0: begin tx_data <= ASCII_M; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd1; end
                            5'd1: begin tx_data <= ASCII_0 + {4'b0, saved_B_id}; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd2; end
                            5'd2: begin tx_data <= ASCII_COLON; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd3; end
                            5'd3: begin tx_data <= ASCII_LBRK; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd4; end
                            5'd4: begin tx_data <= ASCII_0 + {5'b0, target_rows}; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd5; end
                            5'd5: begin tx_data <= ASCII_x; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd6; end
                            5'd6: begin tx_data <= ASCII_0 + {5'b0, target_cols}; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd7; end
                            5'd7: begin tx_data <= ASCII_RBRK; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd8; end
                            5'd8: begin tx_data <= ASCII_CR; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd9; end
                            5'd9: begin tx_data <= ASCII_LF; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd10; end
                            5'd10: begin
                                current_row <= 3'd0;
                                current_col <= 3'd0;
                                state <= S_SET_ADDR_B;
                            end
                            default: header_idx <= 5'd0;
                        endcase
                    end
                    if (wait_tx && !tx_busy) wait_tx <= 1'b0;
                end
                
                //--------------------------------------------------------------
                // 设置读取地址（矩阵B）
                //--------------------------------------------------------------
                S_SET_ADDR_B: begin
                    read_id <= saved_B_id;
                    read_addr <= current_row * 5 + current_col;
                    wait_cycles <= 2'd0;
                    state <= S_LOAD_DATA_B;
                end
                
                //--------------------------------------------------------------
                // 加载数据（矩阵B）- 增加等待周期
                //--------------------------------------------------------------
                S_LOAD_DATA_B: begin
                    if (wait_cycles < 2'd1) begin
                        wait_cycles <= wait_cycles + 1'b1;
                    end else begin
                        current_data <= read_data;
                        wait_cycles <= 2'd0;
                        state <= S_SEND_DATA_B;
                        wait_tx <= 1'b0;
                    end
                end
                
                //--------------------------------------------------------------
                // 发送数据（矩阵B）
                //--------------------------------------------------------------
                S_SEND_DATA_B: begin
                    if (!tx_busy && !wait_tx) begin
                        tx_data <= ASCII_0 + {4'b0, current_data};
                        tx_start <= 1'b1;
                        wait_tx <= 1'b1;
                    end
                    if (wait_tx && !tx_busy) begin
                        wait_tx <= 1'b0;
                        if (current_col == target_cols - 1) begin
                            state <= S_SEND_CR_B;
                        end else begin
                            state <= S_SEND_SP_B;
                        end
                    end
                end
                
                //--------------------------------------------------------------
                // 发送空格（矩阵B）
                //--------------------------------------------------------------
                S_SEND_SP_B: begin
                    if (!tx_busy && !wait_tx) begin
                        tx_data <= ASCII_SPACE;
                        tx_start <= 1'b1;
                        wait_tx <= 1'b1;
                    end
                    if (wait_tx && !tx_busy) begin
                        wait_tx <= 1'b0;
                        current_col <= current_col + 1;
                        state <= S_SET_ADDR_B;
                    end
                end
                
                //--------------------------------------------------------------
                // 发送回车（矩阵B）
                //--------------------------------------------------------------
                S_SEND_CR_B: begin
                    if (!tx_busy && !wait_tx) begin
                        tx_data <= ASCII_CR;
                        tx_start <= 1'b1;
                        wait_tx <= 1'b1;
                    end
                    if (wait_tx && !tx_busy) begin
                        wait_tx <= 1'b0;
                        state <= S_SEND_LF_B;
                    end
                end
                
                //--------------------------------------------------------------
                // 发送换行（矩阵B）
                //--------------------------------------------------------------
                S_SEND_LF_B: begin
                    if (!tx_busy && !wait_tx) begin
                        tx_data <= ASCII_LF;
                        tx_start <= 1'b1;
                        wait_tx <= 1'b1;
                    end
                    if (wait_tx && !tx_busy) begin
                        wait_tx <= 1'b0;
                        if (current_row == target_rows - 1) begin
                            state <= S_DONE;
                        end else begin
                            current_row <= current_row + 1;
                            current_col <= 3'd0;
                            state <= S_SET_ADDR_B;
                        end
                    end
                end
                
                //--------------------------------------------------------------
                // 发送标量值: "x=N\r\n"
                //--------------------------------------------------------------
                S_SEND_SCALAR: begin
                    if (!tx_busy && !wait_tx) begin
                        case (header_idx)
                            5'd0: begin tx_data <= ASCII_x; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd1; end
                            5'd1: begin tx_data <= ASCII_EQ; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd2; end
                            5'd2: begin tx_data <= ASCII_0 + {4'b0, saved_scalar}; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd3; end
                            5'd3: begin tx_data <= ASCII_CR; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd4; end
                            5'd4: begin tx_data <= ASCII_LF; tx_start <= 1'b1; wait_tx <= 1'b1; header_idx <= 5'd5; end
                            5'd5: begin
                                state <= S_DONE;
                            end
                            default: header_idx <= 5'd0;
                        endcase
                    end
                    if (wait_tx && !tx_busy) wait_tx <= 1'b0;
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
