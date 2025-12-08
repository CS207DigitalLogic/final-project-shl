`timescale 1ns / 1ps

module Matrix_System_Top(
    input wire clk,             // 系统时钟 (推荐 50MHz 或 100MHz)
    input wire rst_n,           // 系统复位
    
    // ============================================================
    // 1. 硬件交互接口 (板载开关 & 按键)
    // ============================================================
    // Opcode 定义: 
    // 000: 转置 (A^T)
    // 001: 加法 (A+B)
    // 010: 标量乘 (A*k)
    // 011: 矩阵乘 (A*B)
    // 100: 卷积 (Convolution Bonus)
    input wire [2:0] sw_op_type,
    
    input wire [1:0] sw_id_A,   // 选择运算数 A 的 ID (0~3)
    input wire [1:0] sw_id_B,   // 选择运算数 B 的 ID (0~3)
    input wire [3:0] sw_scalar, // 标量输入 (用于标量乘法)
    input wire btn_start,       // 启动计算按钮
    
    // ============================================================
    // 2. UART 串口接口
    // ============================================================
    input wire uart_rx_valid,       // 接收数据有效脉冲
    input wire [7:0] uart_rx_data,  // 接收到的数据 (假设上位机发的是 Hex 原始值，如 0x03 代表数值 3)
    
    output reg [7:0] uart_tx_data,  // 发送数据总线 (ASCII 字符)
    output reg uart_tx_start,       // 发送请求
    input wire uart_tx_busy,        // 发送忙信号
    
    // ============================================================
    // 3. 状态指示灯
    // ============================================================
    output reg led_error,       // 维度不合法报错
    output reg led_idle,        // 空闲状态
    output reg led_busy,        // 正在计算/传输
    output reg led_done         // 完成一次计算
);

    // ============================================================
    // 参数定义
    // ============================================================
    localparam MAX_ROWS = 5;
    localparam MAX_COLS = 5;
    localparam STORAGE_DEPTH = 4; // 存储 4 个矩阵
    localparam FLATTENED_SIZE = 25;

    // ============================================================
    // 内部存储堆 (Matrix Storage Heap)
    // ============================================================
    // 数据存储：4组 x 25个元素 x 4位宽
    reg [3:0] mem_data [0:STORAGE_DEPTH-1][0:FLATTENED_SIZE-1];
    // 维度存储：4组
    reg [2:0] mem_rows [0:STORAGE_DEPTH-1];
    reg [2:0] mem_cols [0:STORAGE_DEPTH-1];

    // ============================================================
    // 模块 1: UART 接收解析状态机 (RX Parser)
    // ============================================================
    // 协议约定: 
    // 1. 发送 0xAA (帧头) -> 进入录入模式
    // 2. 发送 ID (0~3)
    // 3. 发送 Row (1~5)
    // 4. 发送 Col (1~5)
    // 5. 连续发送 Row*Col 个数据

    localparam RX_IDLE  = 3'd0;
    localparam RX_ID    = 3'd1;
    localparam RX_ROW   = 3'd2;
    localparam RX_COL   = 3'd3;
    localparam RX_DATA  = 3'd4;

    reg [2:0] rx_state;
    reg [1:0] curr_rx_id;
    reg [2:0] curr_rx_r_limit, curr_rx_c_limit; // 当前录入矩阵的维度
    reg [2:0] rx_r_cnt, rx_c_cnt; // 行列计数器

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rx_state <= RX_IDLE;
            curr_rx_id <= 0;
            rx_r_cnt <= 0; rx_c_cnt <= 0;
        end else if(uart_rx_valid) begin
            case(rx_state)
                RX_IDLE: begin
                    if(uart_rx_data == 8'hAA) rx_state <= RX_ID; // 帧头检测
                end
                RX_ID: begin
                    curr_rx_id <= uart_rx_data[1:0];
                    rx_state <= RX_ROW;
                end
                RX_ROW: begin
                    mem_rows[curr_rx_id] <= uart_rx_data[2:0];
                    curr_rx_r_limit <= uart_rx_data[2:0];
                    rx_state <= RX_COL;
                end
                RX_COL: begin
                    mem_cols[curr_rx_id] <= uart_rx_data[2:0];
                    curr_rx_c_limit <= uart_rx_data[2:0];
                    rx_state <= RX_DATA;
                    rx_r_cnt <= 0; rx_c_cnt <= 0; // 重置计数器
                end
                RX_DATA: begin
                    // 智能存储：自动计算一维地址 = r*5 + c
                    mem_data[curr_rx_id][rx_r_cnt * 5 + rx_c_cnt] <= uart_rx_data[3:0];
                    
                    // 更新行列计数
                    if(rx_c_cnt == curr_rx_c_limit - 1) begin
                        rx_c_cnt <= 0;
                        if(rx_r_cnt == curr_rx_r_limit - 1) begin
                            rx_state <= RX_IDLE; // 录入完成
                        end else begin
                            rx_r_cnt <= rx_r_cnt + 1;
                        end
                    end else begin
                        rx_c_cnt <= rx_c_cnt + 1;
                    end
                end
            endcase
        end
    end

    // ============================================================
    // 模块 2: 数据路由与合法性检查 (Routing & Checking)
    // ============================================================
    wire [3:0] core_in_A [0:24];
    wire [3:0] core_in_B [0:24];
    wire [2:0] dim_ra, dim_ca, dim_rb, dim_cb;
    
    // 从仓库取出选定的矩阵
    assign dim_ra = mem_rows[sw_id_A];
    assign dim_ca = mem_cols[sw_id_A];
    assign dim_rb = mem_rows[sw_id_B];
    assign dim_cb = mem_cols[sw_id_B];

    genvar i;
    generate
        for(i=0; i<25; i=i+1) begin : wire_assign
            assign core_in_A[i] = mem_data[sw_id_A][i];
            assign core_in_B[i] = mem_data[sw_id_B][i];
        end
    endgenerate

    // 提取卷积核 (从矩阵A的前3行前3列提取)
    wire [3:0] kernel_flat [0:8];
    assign kernel_flat[0] = mem_data[sw_id_A][0]; assign kernel_flat[1] = mem_data[sw_id_A][1]; assign kernel_flat[2] = mem_data[sw_id_A][2];
    assign kernel_flat[3] = mem_data[sw_id_A][5]; assign kernel_flat[4] = mem_data[sw_id_A][6]; assign kernel_flat[5] = mem_data[sw_id_A][7];
    assign kernel_flat[6] = mem_data[sw_id_A][10];assign kernel_flat[7] = mem_data[sw_id_A][11];assign kernel_flat[8] = mem_data[sw_id_A][12];

    // 启动脉冲逻辑
    reg mat_start, conv_start;
    wire is_conv_mode = (sw_op_type == 3'b100);

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            mat_start <= 0; conv_start <= 0; led_error <= 0;
        end else begin
            mat_start <= 0; conv_start <= 0;
            if(btn_start) begin
                if(is_conv_mode) begin
                    conv_start <= 1; // 卷积无条件启动
                    led_error <= 0;
                end else begin
                    // 矩阵模式维度检查
                    case(sw_op_type)
                        3'b001: begin // 加法 (MxN) == (MxN)
                            if(dim_ra == dim_rb && dim_ca == dim_cb) mat_start <= 1;
                            else led_error <= 1;
                        end
                        3'b011: begin // 乘法 (MxK) * (KxN) -> ca == rb
                            if(dim_ca == dim_rb) mat_start <= 1;
                            else led_error <= 1;
                        end
                        default: mat_start <= 1; // 转置和标量直接启动
                    endcase
                end
            end
        end
    end

    // ============================================================
    // 模块 3: 计算核心实例化 (Core Instantiation)
    // ============================================================
    
    // Core A: 矩阵计算
    wire mat_done;
    wire [15:0] mat_res_flat [0:24];
    wire [2:0] mat_res_r, mat_res_c;
    
    matrix_calculate u_mat_core (
        .clk(clk), .rst_n(rst_n),
        .start(mat_start),
        .opcode(sw_op_type[1:0]),
        .matrix_A_row(dim_ra), .matrix_A_col(dim_ca),
        .matrix_B_row(dim_rb), .matrix_B_col(dim_cb),
        .scalar(sw_scalar),
        .matrix_A(core_in_A), .matrix_B(core_in_B),
        .done(mat_done),
        .matrix_C(mat_res_flat),
        .matrix_C_row(mat_res_r), .matrix_C_col(mat_res_c)
    );

    // Core B: 卷积计算
    wire conv_done;
    wire [15:0] conv_res_pixel;
    wire conv_res_valid;
    
    convolution u_conv_core (
        .clk(clk), .rst_n(rst_n),
        .start(conv_start),
        .kernel_flat(kernel_flat),
        .pixel_out(conv_res_pixel),
        .pixel_valid(conv_res_valid),
        .done(conv_done)
    );

    // ============================================================
    // 模块 4: 输出处理器 (TX Processor) - 最复杂的部分
    // ============================================================
    // 功能：把二进制结果转成 ASCII 码 (如 12 -> '1', '2') 并发送
    
    reg [3:0] tx_state;
    reg [2:0] out_r, out_c; // 输出行列游标
    reg [15:0] current_val; // 当前要发送的数值
    reg [3:0] bcd_thousands, bcd_hundreds, bcd_tens, bcd_units; // BCD 码
    
    // 状态定义
    localparam TX_IDLE      = 4'd0;
    localparam TX_FETCH     = 4'd1; // 取数
    localparam TX_CALC_BCD  = 4'd2; // 转BCD
    localparam TX_SEND_1000 = 4'd3; // 发千位
    localparam TX_SEND_100  = 4'd4; // 发百位
    localparam TX_SEND_10   = 4'd5; // 发十位
    localparam TX_SEND_1    = 4'd6; // 发个位
    localparam TX_SEND_SP   = 4'd7; // 发空格或换行
    localparam TX_NEXT      = 4'd8; // 下一个
    localparam TX_CONV_BUF  = 4'd9; // 卷积模式缓冲

    // 卷积数据缓冲 (因为卷积出数快，串口慢，需要 latch)
    reg [15:0] conv_latch_val;
    reg conv_data_ready;

    // 状态指示灯
    always @(posedge clk) begin
        led_idle <= (tx_state == TX_IDLE);
        led_busy <= (tx_state != TX_IDLE);
    end

    // 核心输出状态机
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            tx_state <= TX_IDLE;
            uart_tx_start <= 0;
            led_done <= 0;
            conv_data_ready <= 0;
        end else begin
            // 默认拉低 TX Start (脉冲信号)
            uart_tx_start <= 0;

            case(tx_state)
                // --- 空闲等待 ---
                TX_IDLE: begin
                    if(mat_done && !is_conv_mode) begin
                        // 矩阵模式完成
                        led_done <= 1;
                        out_r <= 0; out_c <= 0;
                        tx_state <= TX_FETCH;
                    end
                    else if(conv_res_valid && is_conv_mode) begin
                        // 卷积模式：捕获到一个新数据
                        conv_latch_val <= conv_res_pixel;
                        tx_state <= TX_CALC_BCD; // 直接去发送
                    end
                    else if(conv_done && is_conv_mode) begin
                        led_done <= 1; // 卷积全部结束
                    end
                end

                // --- 矩阵模式：取数 ---
                TX_FETCH: begin
                    current_val <= mat_res_flat[out_r * 5 + out_c];
                    tx_state <= TX_CALC_BCD;
                end

                // --- 通用：二进制转 BCD (Binary to BCD) ---
                // 简单起见，这里支持到 9999
                TX_CALC_BCD: begin
                    if (is_conv_mode) current_val <= conv_latch_val;
                    
                    bcd_thousands <= (current_val / 1000) % 10;
                    bcd_hundreds  <= (current_val / 100) % 10;
                    bcd_tens      <= (current_val / 10) % 10;
                    bcd_units     <= current_val % 10;
                    
                    tx_state <= TX_SEND_1000;
                end

                // --- 发送序列：千位 ---
                TX_SEND_1000: begin
                    if(!uart_tx_busy) begin
                        if(bcd_thousands > 0) begin
                            uart_tx_data <= {4'b0011, bcd_thousands}; // '0' + val
                            uart_tx_start <= 1;
                            tx_state <= TX_SEND_100;
                        end else begin
                            tx_state <= TX_SEND_100; // 不发送前导0
                        end
                    end
                end

                // --- 发送序列：百位 ---
                TX_SEND_100: begin
                    if(!uart_tx_busy) begin
                        // 只有当千位有数，或者百位>0时才发
                        if(bcd_hundreds > 0 || bcd_thousands > 0) begin
                            uart_tx_data <= {4'b0011, bcd_hundreds}; 
                            uart_tx_start <= 1;
                            tx_state <= TX_SEND_10;
                        end else begin
                            tx_state <= TX_SEND_10;
                        end
                    end
                end

                // --- 发送序列：十位 ---
                TX_SEND_10: begin
                    if(!uart_tx_busy) begin
                        if(bcd_tens > 0 || bcd_hundreds > 0 || bcd_thousands > 0) begin
                            uart_tx_data <= {4'b0011, bcd_tens};
                            uart_tx_start <= 1;
                            tx_state <= TX_SEND_1;
                        end else begin
                            tx_state <= TX_SEND_1;
                        end
                    end
                end

                // --- 发送序列：个位 (必须发) ---
                TX_SEND_1: begin
                    if(!uart_tx_busy) begin
                        uart_tx_data <= {4'b0011, bcd_units};
                        uart_tx_start <= 1;
                        tx_state <= TX_SEND_SP;
                    end
                end

                // --- 发送分隔符 (空格 或 换行) ---
                TX_SEND_SP: begin
                    if(!uart_tx_busy) begin
                        uart_tx_start <= 1;
                        
                        if(is_conv_mode) begin
                            uart_tx_data <= 8'h20; // 卷积模式全是空格
                            tx_state <= TX_IDLE;   // 发完一个数，回IDLE等下一个
                        end else begin
                            // 矩阵模式：一行结束发换行，否则发空格
                            if(out_c == mat_res_col - 1) uart_tx_data <= 8'h0A; // \n
                            else uart_tx_data <= 8'h20; // Space
                            tx_state <= TX_NEXT;
                        end
                    end
                end

                // --- 矩阵模式：游标更新 ---
                TX_NEXT: begin
                    if(!uart_tx_busy) begin // 确保分隔符发完了
                        if(out_c == mat_res_col - 1) begin
                            out_c <= 0;
                            if(out_r == mat_res_row - 1) tx_state <= TX_IDLE; // 全部发完
                            else begin
                                out_r <= out_r + 1;
                                tx_state <= TX_FETCH; // 继续下一行
                            end
                        end else begin
                            out_c <= out_c + 1;
                            tx_state <= TX_FETCH; // 继续下一列
                        end
                    end
                end
                
                default: tx_state <= TX_IDLE;
            endcase
        end
    end

endmodule