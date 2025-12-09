`timescale 1ns / 1ps

module Matrix_System_Top(
    input wire clk,             
    input wire rst_n,           
    
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
    input wire btn_confirm,     // 确认按钮
    input wire [3:0] sw_countdown, // 倒计时设置 (5-15秒)
    input wire sw_manual_mode,  // 手动/随机模式选择
    
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
    output reg led_done,        // 完成一次计算
    
    // ============================================================
    // 4. 七段数码管接口
    // ============================================================
    output wire [6:0] seg_display,   // 七段显示 (a~g)
    output wire [3:0] seg_select     // 位选择 (4位数码管)
);

    // ============================================================
    // 参数定义
    // ============================================================
    localparam MAX_ROWS = 5;
    localparam MAX_COLS = 5;
    localparam STORAGE_DEPTH = 4; // 存储 4 个矩阵
    localparam FLATTENED_SIZE = 25;
    localparam CLK_FREQ = 100_000_000; // 100MHz 时钟频率

    // ============================================================
    // 内部存储堆 (Matrix Storage Heap)
    // ============================================================
    // 数据存储：4组 x 25个元素 x 4位宽
    reg [3:0] mem_data [0:STORAGE_DEPTH-1][0:FLATTENED_SIZE-1];
    // 维度存储：4组
    reg [2:0] mem_rows [0:STORAGE_DEPTH-1];
    reg [2:0] mem_cols [0:STORAGE_DEPTH-1];
    // 矩阵计数
    reg [2:0] mat_count;
    
    // ============================================================
    // 七段数码管显示信号
    // ============================================================
    reg [3:0] seg_digit0, seg_digit1, seg_digit2, seg_digit3; // 4位显示数值
    wire [3:0] countdown_display;     // 倒计时显示值
    wire [3:0] op_type_display;       // 运算类型显示值
    wire       timer_timeout;         // 倒计时超时信号
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

    // 提取卷积核 (从矩阵A提取，支持1x1到3x3)
    wire [3:0] kernel_flat [0:8];
    assign kernel_flat[0] = mem_data[sw_id_A][0]; assign kernel_flat[1] = mem_data[sw_id_A][1]; assign kernel_flat[2] = mem_data[sw_id_A][2];
    assign kernel_flat[3] = mem_data[sw_id_A][5]; assign kernel_flat[4] = mem_data[sw_id_A][6]; assign kernel_flat[5] = mem_data[sw_id_A][7];
    assign kernel_flat[6] = mem_data[sw_id_A][10];assign kernel_flat[7] = mem_data[sw_id_A][11];assign kernel_flat[8] = mem_data[sw_id_A][12];

    // ============================================================
    // 卷积合法性验证器实例化
    // ============================================================
    wire conv_valid;
    wire [3:0] conv_out_row, conv_out_col;
    
    convoluter_validator u_conv_validator (
        .kernel_row(dim_ra[2:0]),   // 卷积核用矩阵A的维度
        .kernel_col(dim_ca[2:0]),
        .image_row({1'b0, dim_rb}), // 图像用矩阵B的维度
        .image_col({1'b0, dim_cb}),
        .valid_conv(conv_valid),
        .output_row(conv_out_row),
        .output_col(conv_out_col)
    );

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
                    // 卷积模式：需要验证卷积核与图像尺寸
                    if(conv_valid) begin
                        conv_start <= 1;
                        led_error <= 0;
                    end else begin
                        led_error <= 1; // 卷积尺寸不合法
                    end
                end else begin
                    // 矩阵模式维度检查
                    case(sw_op_type)
                        3'b001: begin // 加法 (MxN) == (MxN)
                            if(dim_ra == dim_rb && dim_ca == dim_cb) begin
                                mat_start <= 1;
                                led_error <= 0;
                            end else led_error <= 1;
                        end
                        3'b011: begin // 乘法 (MxK) * (KxN) -> ca == rb
                            if(dim_ca == dim_rb) begin
                                mat_start <= 1;
                                led_error <= 0;
                            end else led_error <= 1;
                        end
                        default: begin
                            mat_start <= 1; // 转置和标量直接启动
                            led_error <= 0;
                        end
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

    // Core B: 卷积计算 (使用新的 convoluter 模块)
    wire conv_done;
    wire [15:0] conv_res_flat [0:24];
    wire [2:0] conv_res_r, conv_res_c;
    
    convoluter u_conv_core (
        .clk(clk), .rst_n(rst_n),
        .start(conv_start),
        // 图像输入 (使用矩阵B作为图像)
        .image_flat(core_in_B),
        .image_row(dim_rb),
        .image_col(dim_cb),
        // 卷积核输入 (使用矩阵A作为卷积核)
        .kernel_flat(kernel_flat),
        .kernel_row(dim_ra[1:0]),
        .kernel_col(dim_ca[1:0]),
        // 输出
        .done(conv_done),
        .result_flat(conv_res_flat),
        .result_row(conv_res_r),
        .result_col(conv_res_c)
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

    // 卷积结果维度寄存器 (用于TX状态机)
    reg [2:0] conv_out_r_reg, conv_out_c_reg;

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
            conv_out_r_reg <= 0;
            conv_out_c_reg <= 0;
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
                    else if(conv_done && is_conv_mode) begin
                        // 卷积模式完成：开始输出结果矩阵
                        led_done <= 1;
                        out_r <= 0; out_c <= 0;
                        conv_out_r_reg <= conv_res_r;
                        conv_out_c_reg <= conv_res_c;
                        tx_state <= TX_FETCH;
                    end
                end

                // --- 取数 (矩阵模式和卷积模式统一处理) ---
                TX_FETCH: begin
                    if(is_conv_mode) begin
                        current_val <= conv_res_flat[out_r * 5 + out_c];
                    end else begin
                        current_val <= mat_res_flat[out_r * 5 + out_c];
                    end
                    tx_state <= TX_CALC_BCD;
                end

                // --- 通用：二进制转 BCD (Binary to BCD) ---
                // 简单起见，这里支持到 9999
                TX_CALC_BCD: begin
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
                        
                        // 获取当前结果矩阵的列数
                        if(is_conv_mode) begin
                            // 卷积模式：按矩阵格式输出
                            if(out_c == conv_out_c_reg - 1) uart_tx_data <= 8'h0A; // \n
                            else uart_tx_data <= 8'h20; // Space
                        end else begin
                            // 矩阵模式：一行结束发换行，否则发空格
                            if(out_c == mat_res_c - 1) uart_tx_data <= 8'h0A; // \n
                            else uart_tx_data <= 8'h20; // Space
                        end
                        tx_state <= TX_NEXT;
                    end
                end

                // --- 游标更新 (矩阵模式和卷积模式统一处理) ---
                TX_NEXT: begin
                    if(!uart_tx_busy) begin // 确保分隔符发完了
                        // 获取当前结果矩阵的行列数
                        if(is_conv_mode) begin
                            if(out_c == conv_out_c_reg - 1) begin
                                out_c <= 0;
                                if(out_r == conv_out_r_reg - 1) tx_state <= TX_IDLE; // 全部发完
                                else begin
                                    out_r <= out_r + 1;
                                    tx_state <= TX_FETCH; // 继续下一行
                                end
                            end else begin
                                out_c <= out_c + 1;
                                tx_state <= TX_FETCH; // 继续下一列
                            end
                        end else begin
                            if(out_c == mat_res_c - 1) begin
                                out_c <= 0;
                                if(out_r == mat_res_r - 1) tx_state <= TX_IDLE; // 全部发完
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
                end
                
                default: tx_state <= TX_IDLE;
            endcase
        end
    end

    // ============================================================
    // 模块 5: 矩阵计数管理
    // ============================================================
    // 当通过UART录入新矩阵时，更新矩阵计数
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mat_count <= 3'd0;
        end else begin
            // 当录入完成时，更新计数
            if (rx_state == RX_DATA && uart_rx_valid) begin
                if (rx_c_cnt == curr_rx_c_limit - 1 && rx_r_cnt == curr_rx_r_limit - 1) begin
                    // 检查是否是新矩阵还是覆盖已有矩阵
                    if (curr_rx_id >= mat_count) begin
                        mat_count <= curr_rx_id + 1;
                    end
                end
            end
        end
    end

    // ============================================================
    // 模块 6: 倒计时器实例化
    // ============================================================
    reg  timer_start_pulse;
    reg  timer_reset_pulse;
    wire [3:0] timer_set_seconds;
    
    // 倒计时设置：5-15秒，默认10秒
    assign timer_set_seconds = (sw_countdown >= 4'd5 && sw_countdown <= 4'd15) ? 
                                sw_countdown : 4'd10;
    
    timer #(
        .CLK_FREQ(CLK_FREQ)
    ) u_timer (
        .clk(clk),
        .rst_n(rst_n),
        .start(timer_start_pulse),
        .reset(timer_reset_pulse),
        .set_seconds(timer_set_seconds),
        .timeout_flag(timer_timeout),
        .current_seconds(countdown_display)
    );
    
    // ============================================================
    // 模块 7: 加法和乘法验证器
    // ============================================================
    wire add_valid;
    wire mul_valid;
    wire [2:0] mul_result_row, mul_result_col;
    
    adder_validator u_add_validator (
        .a_row(dim_ra),
        .a_col(dim_ca),
        .b_row(dim_rb),
        .b_col(dim_cb),
        .valid_add(add_valid)
    );
    
    multiplexer_validator u_mul_validator (
        .a_row(dim_ra),
        .a_col(dim_ca),
        .b_row(dim_rb),
        .b_col(dim_cb),
        .valid_mul(mul_valid),
        .result_row(mul_result_row),
        .result_col(mul_result_col)
    );
    
    // ============================================================
    // 模块 8: 七段数码管显示控制
    // ============================================================
    // 显示内容：
    // - 位0: 运算类型 (0-4 对应 T/A/B/C/J)
    // - 位1-2: 保留
    // - 位3: 倒计时秒数
    
    // 运算类型编码到显示
    assign op_type_display = {1'b0, sw_op_type};
    
    // 显示数据选择
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            seg_digit0 <= 4'd0;
            seg_digit1 <= 4'd0;
            seg_digit2 <= 4'd0;
            seg_digit3 <= 4'd0;
            timer_start_pulse <= 1'b0;
            timer_reset_pulse <= 1'b1;
        end else begin
            timer_start_pulse <= 1'b0;
            timer_reset_pulse <= 1'b0;
            
            // 根据当前状态选择显示内容
            if (led_error && !conv_valid && is_conv_mode) begin
                // 卷积不合法：显示倒计时
                seg_digit3 <= countdown_display;
                seg_digit2 <= 4'hE; // 'E' 表示 Error
                seg_digit1 <= 4'hE;
                seg_digit0 <= op_type_display;
                
                // 启动倒计时
                if (!timer_timeout) begin
                    timer_start_pulse <= 1'b1;
                end
            end else if (led_error) begin
                // 其他运算不合法
                seg_digit3 <= countdown_display;
                seg_digit2 <= 4'hE;
                seg_digit1 <= 4'hE;
                seg_digit0 <= op_type_display;
                
                if (!timer_timeout) begin
                    timer_start_pulse <= 1'b1;
                end
            end else begin
                // 正常显示
                timer_reset_pulse <= 1'b1;
                seg_digit3 <= mat_count[2:0];           // 矩阵总数
                seg_digit2 <= {2'b00, sw_id_A};         // 操作数A的ID
                seg_digit1 <= {2'b00, sw_id_B};         // 操作数B的ID
                seg_digit0 <= op_type_display;          // 运算类型
            end
        end
    end
    
    // ============================================================
    // 模块 9: 七段数码管扫描驱动
    // ============================================================
    // 扫描频率：约1kHz (100MHz / 100000)
    reg [16:0] scan_cnt;
    reg [1:0]  scan_sel;
    reg [3:0]  scan_digit;
    reg [6:0]  seg_pattern;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scan_cnt <= 17'd0;
            scan_sel <= 2'd0;
        end else begin
            if (scan_cnt == 17'd99999) begin
                scan_cnt <= 17'd0;
                scan_sel <= scan_sel + 1;
            end else begin
                scan_cnt <= scan_cnt + 1;
            end
        end
    end
    
    // 位选择逻辑
    assign seg_select = ~(4'b0001 << scan_sel); // 低电平有效
    
    // 当前显示位的数值
    always @(*) begin
        case (scan_sel)
            2'd0: scan_digit = seg_digit0;
            2'd1: scan_digit = seg_digit1;
            2'd2: scan_digit = seg_digit2;
            2'd3: scan_digit = seg_digit3;
            default: scan_digit = 4'd0;
        endcase
    end
    
    // 七段译码 (共阴极，高电平点亮)
    // 段排列: seg_display[6:0] = {g, f, e, d, c, b, a}
    always @(*) begin
        case (scan_digit)
            4'h0: seg_pattern = 7'b0111111; // 0
            4'h1: seg_pattern = 7'b0000110; // 1
            4'h2: seg_pattern = 7'b1011011; // 2
            4'h3: seg_pattern = 7'b1001111; // 3
            4'h4: seg_pattern = 7'b1100110; // 4
            4'h5: seg_pattern = 7'b1101101; // 5
            4'h6: seg_pattern = 7'b1111101; // 6
            4'h7: seg_pattern = 7'b0000111; // 7
            4'h8: seg_pattern = 7'b1111111; // 8
            4'h9: seg_pattern = 7'b1101111; // 9
            4'hA: seg_pattern = 7'b1110111; // A
            4'hB: seg_pattern = 7'b1111100; // b
            4'hC: seg_pattern = 7'b0111001; // C
            4'hD: seg_pattern = 7'b1011110; // d
            4'hE: seg_pattern = 7'b1111001; // E
            4'hF: seg_pattern = 7'b1110001; // F
            default: seg_pattern = 7'b0000000;
        endcase
    end
    
    assign seg_display = seg_pattern;

endmodule