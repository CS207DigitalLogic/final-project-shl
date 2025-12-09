`timescale 1ns / 1ps
//==============================================================================
// integrated_top.v
// FPGA 矩阵计算器 - 整合顶层模块
// 整合 part_lyx (主控FSM+UART) + part_hcz (倒计时) + part_shl (矩阵运算)
//==============================================================================

module integrated_top (
    input wire clk,              // 100MHz 主时钟
    input wire rst_n,            // 复位 (低有效)

    //==========================================================================
    // 拨码开关
    //==========================================================================
    input wire [7:0] sw,         // sw[7:5]=菜单选择, sw[4:3]=设置, sw[2:0]=运算类型
    input wire [3:0] sw_scalar,  // 标量输入 / 倒计时设置

    //==========================================================================
    // 按键 (Active High, 需消抖)
    //==========================================================================
    input wire btn_confirm,      // 确认键
    input wire btn_send,         // UART发送键

    //==========================================================================
    // UART 物理接口
    //==========================================================================
    input  wire uart_rx,         // UART 接收线
    output wire uart_tx,         // UART 发送线

    //==========================================================================
    // LED 指示灯
    //==========================================================================
    output wire led_error,       // 运算错误
    output wire led_idle,        // 空闲状态
    output wire led_busy,        // 忙碌状态
    output wire led_done,        // 完成指示

    //==========================================================================
    // 七段数码管 (假设8个数码管, 直接驱动)
    //==========================================================================
    output wire [7:0] seg_data,  // 段选数据
    output wire [7:0] seg_sel    // 位选 (低有效)
);

    //==========================================================================
    // 参数定义
    //==========================================================================
    localparam CLK_FREQ   = 100_000_000;
    localparam BAUD_RATE  = 115200;
    localparam MAX_MATRICES = 4;
    localparam MAX_DIM    = 5;

    //==========================================================================
    // 按键消抖
    //==========================================================================
    wire confirm_pulse;
    wire send_pulse;

    // 使用 part_lyx 的 debounce 模块
    debounce u_debounce_confirm (
        .clk(clk),
        .rst_n(rst_n),
        .key_in(btn_confirm),
        .key_flag(confirm_pulse)
    );

    debounce u_debounce_send (
        .clk(clk),
        .rst_n(rst_n),
        .key_in(btn_send),
        .key_flag(send_pulse)
    );

    //==========================================================================
    // 主状态机 (来自 part_lyx)
    //==========================================================================
    localparam S_MENU      = 4'd0;
    localparam S_INPUTER   = 4'd1;   // 矩阵输入
    localparam S_GENERATOR = 4'd2;   // 矩阵生成
    localparam S_DISPLAYER = 4'd3;   // 矩阵展示
    localparam S_OPERATOR  = 4'd4;   // 矩阵运算
    localparam S_SETTINGS  = 4'd5;   // 设置

    // 运算子状态
    localparam S_OP_T      = 4'd6;   // 转置
    localparam S_OP_A      = 4'd7;   // 加法
    localparam S_OP_B      = 4'd8;   // 标量乘
    localparam S_OP_C      = 4'd9;   // 矩阵乘
    localparam S_OP_J      = 4'd10;  // 卷积

    reg [3:0] state, state_next;

    // 输入解码
    wire [2:0] menu_sel = sw[7:5];
    wire [2:0] op_sel   = sw[2:0];

    //==========================================================================
    // UART 模块 (来自 part_lyx)
    //==========================================================================
    // UART RX
    wire [7:0] uart_rx_data;
    wire       uart_rx_done;

    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) u_uart_rx (
        .clk(clk),
        .rst_n(rst_n),
        .rx(uart_rx),
        .rx_data(uart_rx_data),
        .rx_done(uart_rx_done)
    );

    // UART TX
    reg  [7:0] tx_data_reg;
    reg        tx_start_reg;
    wire       tx_busy;

    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) u_uart_tx (
        .clk(clk),
        .rst_n(rst_n),
        .tx_start(tx_start_reg),
        .tx_data(tx_data_reg),
        .tx(uart_tx),
        .tx_busy(tx_busy)
    );

    //==========================================================================
    // 矩阵存储 (来自 part_shl)
    //==========================================================================
    reg [3:0]  mem_data [0:MAX_MATRICES-1][0:24];  // 4个矩阵, 每个最多25元素
    reg [2:0]  mem_rows [0:MAX_MATRICES-1];        // 行数
    reg [2:0]  mem_cols [0:MAX_MATRICES-1];        // 列数
    reg [2:0]  mat_count;                          // 矩阵总数

    //==========================================================================
    // 矩阵输入解析器 (UART RX -> 存储)
    //==========================================================================
    localparam RX_IDLE = 3'd0;
    localparam RX_ROW  = 3'd1;
    localparam RX_COL  = 3'd2;
    localparam RX_DATA = 3'd3;

    reg [2:0] rx_state;
    reg [1:0] curr_mat_id;           // 当前录入的矩阵ID
    reg [2:0] curr_row, curr_col;    // 当前录入位置
    reg [2:0] target_rows, target_cols;
    reg       input_error;           // 输入错误标志

    // 矩阵输入状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state <= RX_IDLE;
            curr_mat_id <= 2'd0;
            curr_row <= 3'd0;
            curr_col <= 3'd0;
            target_rows <= 3'd0;
            target_cols <= 3'd0;
            input_error <= 1'b0;
        end else if (state == S_INPUTER && uart_rx_done) begin
            case (rx_state)
                RX_IDLE: begin
                    // 等待输入行数
                    if (uart_rx_data >= 8'd1 && uart_rx_data <= 8'd5) begin
                        target_rows <= uart_rx_data[2:0];
                        input_error <= 1'b0;
                        rx_state <= RX_COL;
                    end else begin
                        input_error <= 1'b1;  // 维度错误
                    end
                end

                RX_COL: begin
                    // 等待输入列数
                    if (uart_rx_data >= 8'd1 && uart_rx_data <= 8'd5) begin
                        target_cols <= uart_rx_data[2:0];
                        mem_rows[curr_mat_id] <= target_rows;
                        mem_cols[curr_mat_id] <= uart_rx_data[2:0];
                        curr_row <= 3'd0;
                        curr_col <= 3'd0;
                        input_error <= 1'b0;
                        rx_state <= RX_DATA;
                    end else begin
                        input_error <= 1'b1;
                    end
                end

                RX_DATA: begin
                    // 输入矩阵元素
                    if (uart_rx_data <= 8'd9) begin
                        mem_data[curr_mat_id][curr_row * 5 + curr_col] <= uart_rx_data[3:0];
                        input_error <= 1'b0;

                        // 更新位置
                        if (curr_col == target_cols - 1) begin
                            curr_col <= 3'd0;
                            if (curr_row == target_rows - 1) begin
                                // 矩阵输入完成
                                rx_state <= RX_IDLE;
                                if (curr_mat_id < MAX_MATRICES - 1)
                                    curr_mat_id <= curr_mat_id + 1;
                                else
                                    curr_mat_id <= 2'd0;  // 循环覆盖
                                
                                // 更新矩阵计数
                                if (mat_count < MAX_MATRICES)
                                    mat_count <= mat_count + 1;
                            end else begin
                                curr_row <= curr_row + 1;
                            end
                        end else begin
                            curr_col <= curr_col + 1;
                        end
                    end else begin
                        input_error <= 1'b1;  // 元素值错误
                    end
                end
            endcase
        end else if (state != S_INPUTER) begin
            rx_state <= RX_IDLE;
        end
    end

    //==========================================================================
    // 倒计时器 (来自 part_hcz 的概念, 简化集成)
    //==========================================================================
    reg [31:0] countdown_counter;
    reg [3:0]  countdown_seconds;
    reg        countdown_active;
    reg        countdown_timeout;

    wire [3:0] countdown_setting = (sw_scalar >= 4'd5 && sw_scalar <= 4'd15) ? 
                                    sw_scalar : 4'd10;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            countdown_counter <= 32'd0;
            countdown_seconds <= 4'd0;
            countdown_active <= 1'b0;
            countdown_timeout <= 1'b0;
        end else begin
            countdown_timeout <= 1'b0;

            if (countdown_active) begin
                if (countdown_counter >= CLK_FREQ - 1) begin
                    countdown_counter <= 32'd0;
                    if (countdown_seconds > 0) begin
                        countdown_seconds <= countdown_seconds - 1;
                    end else begin
                        countdown_active <= 1'b0;
                        countdown_timeout <= 1'b1;
                    end
                end else begin
                    countdown_counter <= countdown_counter + 1;
                end
            end
        end
    end

    // 启动倒计时的控制信号
    reg start_countdown;
    always @(posedge clk) begin
        if (start_countdown && !countdown_active) begin
            countdown_active <= 1'b1;
            countdown_seconds <= countdown_setting;
            countdown_counter <= 32'd0;
        end
    end

    //==========================================================================
    // 运算数选择与验证
    //==========================================================================
    reg [1:0] operand1_id, operand2_id;
    reg       operands_valid;
    wire      add_valid, mul_valid;
    wire [2:0] mul_res_row, mul_res_col;

    // 加法验证器
    adder_validator u_add_val (
        .a_row(mem_rows[operand1_id]),
        .a_col(mem_cols[operand1_id]),
        .b_row(mem_rows[operand2_id]),
        .b_col(mem_cols[operand2_id]),
        .valid_add(add_valid)
    );

    // 乘法验证器
    multiplexer_validator u_mul_val (
        .a_row(mem_rows[operand1_id]),
        .a_col(mem_cols[operand1_id]),
        .b_row(mem_rows[operand2_id]),
        .b_col(mem_cols[operand2_id]),
        .valid_mul(mul_valid),
        .result_row(mul_res_row),
        .result_col(mul_res_col)
    );

    //==========================================================================
    // 矩阵计算核心 (来自 part_shl)
    //==========================================================================
    // 这里简化处理，实际需要实例化 matrix_calculate 模块
    reg        calc_start;
    reg        calc_done;
    reg [15:0] calc_result [0:24];
    reg [2:0]  result_rows, result_cols;

    //==========================================================================
    // 主状态机
    //==========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= S_MENU;
        else
            state <= state_next;
    end

    always @(*) begin
        state_next = state;
        start_countdown = 1'b0;

        case (state)
            S_MENU: begin
                if (confirm_pulse) begin
                    case (menu_sel)
                        3'b001: state_next = S_INPUTER;
                        3'b010: state_next = S_GENERATOR;
                        3'b011: state_next = S_DISPLAYER;
                        3'b100: state_next = S_OPERATOR;
                        3'b101: state_next = S_SETTINGS;
                        default: state_next = S_MENU;
                    endcase
                end
            end

            S_INPUTER, S_GENERATOR, S_DISPLAYER: begin
                if (confirm_pulse && menu_sel == 3'b000)
                    state_next = S_MENU;
            end

            S_OPERATOR: begin
                if (confirm_pulse) begin
                    if (menu_sel == 3'b000)
                        state_next = S_MENU;
                    else if (menu_sel == 3'b100) begin
                        case (op_sel)
                            3'b000: state_next = S_OP_T;
                            3'b001: state_next = S_OP_A;
                            3'b010: state_next = S_OP_B;
                            3'b011: state_next = S_OP_C;
                            3'b100: state_next = S_OP_J;
                            default: state_next = S_OPERATOR;
                        endcase
                    end
                end
            end

            S_OP_T, S_OP_A, S_OP_B, S_OP_C, S_OP_J: begin
                if (confirm_pulse && menu_sel == 3'b000)
                    state_next = S_MENU;
                else if (confirm_pulse && menu_sel == 3'b100)
                    state_next = S_OPERATOR;
            end

            S_SETTINGS: begin
                if (confirm_pulse && menu_sel == 3'b000)
                    state_next = S_MENU;
            end
        endcase
    end

    //==========================================================================
    // LED 输出
    //==========================================================================
    assign led_error = input_error;
    assign led_idle  = (state == S_MENU);
    assign led_busy  = countdown_active || (state >= S_OP_T && state <= S_OP_J);
    assign led_done  = calc_done;

    //==========================================================================
    // 七段数码管显示
    //==========================================================================
    // 显示内容: 当前状态 + 倒计时
    reg [3:0] display_digits [0:7];

    // 状态显示编码
    localparam SEG_0 = 8'b1100_0000;
    localparam SEG_1 = 8'b1111_1001;
    localparam SEG_2 = 8'b1010_0100;
    localparam SEG_3 = 8'b1011_0000;
    localparam SEG_4 = 8'b1001_1001;
    localparam SEG_5 = 8'b1001_0010;
    localparam SEG_6 = 8'b1000_0010;
    localparam SEG_7 = 8'b1111_1000;
    localparam SEG_8 = 8'b1000_0000;
    localparam SEG_9 = 8'b1001_0000;
    localparam SEG_A = 8'b1000_1000;
    localparam SEG_B = 8'b1000_0011;
    localparam SEG_C = 8'b1100_0110;
    localparam SEG_T = 8'b1000_0111;
    localparam SEG_J = 8'b1110_0001;
    localparam SEG_BLANK = 8'b1111_1111;

    // 数码管扫描
    reg [15:0] scan_counter;
    reg [2:0]  scan_digit;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scan_counter <= 16'd0;
            scan_digit <= 3'd0;
        end else begin
            if (scan_counter >= 16'd50000) begin  // ~2kHz 扫描
                scan_counter <= 16'd0;
                scan_digit <= scan_digit + 1;
            end else begin
                scan_counter <= scan_counter + 1;
            end
        end
    end

    // 位选输出 (低有效)
    assign seg_sel = ~(8'b0000_0001 << scan_digit);

    // 段选输出
    reg [7:0] current_seg;
    always @(*) begin
        case (scan_digit)
            3'd0: begin
                // 显示运算类型
                case (state)
                    S_OP_T:  current_seg = SEG_T;
                    S_OP_A:  current_seg = SEG_A;
                    S_OP_B:  current_seg = SEG_B;
                    S_OP_C:  current_seg = SEG_C;
                    S_OP_J:  current_seg = SEG_J;
                    default: current_seg = SEG_BLANK;
                endcase
            end
            3'd7: begin
                // 显示倒计时
                case (countdown_seconds)
                    4'd0: current_seg = SEG_0;
                    4'd1: current_seg = SEG_1;
                    4'd2: current_seg = SEG_2;
                    4'd3: current_seg = SEG_3;
                    4'd4: current_seg = SEG_4;
                    4'd5: current_seg = SEG_5;
                    4'd6: current_seg = SEG_6;
                    4'd7: current_seg = SEG_7;
                    4'd8: current_seg = SEG_8;
                    4'd9: current_seg = SEG_9;
                    default: current_seg = SEG_BLANK;
                endcase
            end
            default: current_seg = SEG_BLANK;
        endcase
    end

    assign seg_data = current_seg;

    //==========================================================================
    // 初始化
    //==========================================================================
    integer i, j;
    initial begin
        mat_count = 3'd0;
        for (i = 0; i < MAX_MATRICES; i = i + 1) begin
            mem_rows[i] = 3'd0;
            mem_cols[i] = 3'd0;
            for (j = 0; j < 25; j = j + 1) begin
                mem_data[i][j] = 4'd0;
            end
        end
    end

endmodule
