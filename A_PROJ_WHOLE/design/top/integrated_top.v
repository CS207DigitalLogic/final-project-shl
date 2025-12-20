`timescale 1ns / 1ps
//==============================================================================
// integrated_top.v
// FPGA 矩阵计算器 - 整合顶层模块
// 整合 part_lyx (主控FSM+UART) + part_hcz (倒计时) + part_shl (矩阵运算)
//==============================================================================

module integrated_top (
    input wire clk,              // 100MHz 主时钟
    input wire rst_n,            // 复位 (低有效)

    // 拨码开关
    input wire [7:0] sw_right,   // sw[7:5]=菜单选择, sw[4:3]=设置, sw[2:0]=运算类型
    input wire [7:0] sw_left,    // [5:2]=标量选择/倒计时选择，[2:0]=矩阵选择

    // 按键 (Active High, 需消抖)
    input wire btn_confirm,      // 确认键
    input wire btn_send,         // UART发送键

    // UART physical IO
    input  wire uart_rx,         // UART 接收线
    output wire uart_tx,         // UART 发送线

    // UART control signals
    // input  wire uart_tx_rst_n,   // UART TX reset (active low)
    // input  wire uart_rx_rst_n,   // UART RX reset (active low)

    // LED 
    output wire led_error,       // 错误指示
    output wire led_idle,        // 空闲状态
    output wire led_busy,        // 忙碌状态
    output wire led_done,        // 完成指示

    output reg LED1_uart_tx,      // UART TX working indicator
    output reg LED0_uart_rx,      // UART RX working indicator

    // 7-segment displays
    output reg [7:0] seg0,        // DK1-DK4 segment bus
    output reg [7:0] seg1,        // DK5-DK8 segment bus

    // digit enable
    output reg dk1_en,
    output reg dk4_en,
    output reg dk7_en,
    output reg dk8_en
);


// Internal UART work indicators
wire uart_tx_work = 1;
wire uart_rx_work = 1;

// Internal error flag
reg  error_flag;

//==========================================================================
// 1. 主参数定义
//==========================================================================
localparam CLK_FREQ   = 100_000_000;  // uart
localparam BAUD_RATE  = 115200;       // uart
localparam MAX_MATRICES = 15;
localparam PTR_WIDTH    = 4;

//======================================================================
// 2. input decode
//======================================================================
wire [2:0] menu_sel = sw_right[7:5];  // main menu selection
wire [2:0] op_sel   = sw_right[2:0];  // operator sub-function selection
wire [1:0] setting_sel = sw_right[4:3]; // setting selection 
wire [3:0] scalar_input = sw_left[7:4]; // scalar input for scalar multiplication
wire [3:0] count_down_input = sw_left[7:4]; // countdown input
wire [2:0] matrix_limit_input_preview = sw_left[7:5]; // matrix per type limit input
wire [2:0] operand1_id = sw_left[7:5]; // operand 1 matrix ID
wire [2:0] operand2_id = sw_left[4:2]; // operand 2 matrix ID
wire [2:0] row_input = sw_left[5:3]; // 行数输入 for Operand Selector
wire [2:0] col_input = sw_left[2:0]; // 列数输入 for Operand Selector
wire [2:0] matrix_select = sw_left[2:0]; // 矩阵选择输入 for Operand Selector
//======================================================================
// 3. Debounce modules
//======================================================================

// confirm button debounce
wire confirm_flag;  // single-cycle pulse for FSM
wire send_flag;     // single-cycle pulse for UART TX

debounce u_db_confirm(
    .clk(clk),
    .rst_n(rst_n),
    .key_in(btn_confirm),
    .key_flag(confirm_flag)
);

// send button debounce
debounce u_db_send(
    .clk(clk),
    .rst_n(rst_n),
    .key_in(btn_send),
    .key_flag(send_flag)
);

//==========================================================================
// 4. FSM state encoding
//==========================================================================
localparam S_MENU      = 4'd0;
localparam S_INPUTER   = 4'd1;   // 矩阵输入
localparam S_GENERATOR = 4'd2;   // 矩阵生成
localparam S_DISPLAYER = 4'd3;   // 矩阵展示
localparam S_OPERATOR  = 4'd4;   // 矩阵运算
localparam S_SETTINGS  = 4'd5;   // 设置

// operator sub-FSM
localparam S_OP_T      = 4'd6;   // 转置
localparam S_OP_A      = 4'd7;   // 加法
localparam S_OP_B      = 4'd8;   // 标量乘
localparam S_OP_C      = 4'd9;   // 矩阵乘
localparam S_OP_J      = 4'd10;  // 卷积

// settings sub-FSM
localparam S_SE_n      = 4'd11;  // 每规格矩阵数量上限
localparam S_SE_c      = 4'd12;  // 倒计时秒数（5~15），默认10
localparam S_SE_r      = 4'd13;  // 元素范围（默认 0-9）

reg [3:0] state, state_next;

//==========================================================================
// 5. 主状态机
//==========================================================================
// a. Sequential logic (reset -> S_MENU)
always @(posedge clk, negedge rst_n) begin
    if (!rst_n)
        state <= S_MENU;
    else
        state <= state_next;
end

// b. FSM combinational logic: main menu control
always @(*) begin
    state_next = state;

    case (state)
        // main menu -> main functions, (right)SW7-SW5 + confirm btn
        S_MENU: begin
            if (confirm_flag) begin
                case (menu_sel)
                    3'b000: state_next = S_MENU;
                    3'b001: state_next = S_INPUTER;
                    3'b010: state_next = S_GENERATOR;
                    3'b011: state_next = S_DISPLAYER;
                    3'b100: state_next = S_OPERATOR;
                    3'b101: state_next = S_SETTINGS;
                    default: state_next = S_MENU;
                endcase
            end
        end

        // main functions -> main functions &
        // back to menu, (right)SW7-SW5 + confirm btn
        S_INPUTER, 
        S_GENERATOR,  
        S_DISPLAYER: begin
            if (confirm_flag) begin
                case (menu_sel)
                    3'b000: state_next = S_MENU;
                    3'b001: state_next = S_INPUTER;
                    3'b010: state_next = S_GENERATOR;
                    3'b011: state_next = S_DISPLAYER;
                    3'b100: state_next = S_OPERATOR;
                    3'b101: state_next = S_SETTINGS;
                    default: state_next = S_MENU;
                endcase
            end
        end

        // operator -> operator sub-states, (right)SW2-SW0 + confirm btn
        S_OPERATOR: begin
            if (confirm_flag) begin
                // jump to main functions or menu
                case (menu_sel)
                    3'b000: state_next = S_MENU;
                    3'b001: state_next = S_INPUTER;
                    3'b010: state_next = S_GENERATOR;
                    3'b011: state_next = S_DISPLAYER;
                    3'b100: state_next = S_OPERATOR;
                    3'b101: state_next = S_SETTINGS;
                    default: ; // stay in current state
                endcase
                
                // jump to operator sub-states
                if (menu_sel == 3'b100) begin
                    case (op_sel)
                        3'b000: state_next = S_OP_T;
                        3'b001: state_next = S_OP_A;
                        3'b010: state_next = S_OP_B;
                        3'b011: state_next = S_OP_C;
                        3'b100: state_next = S_OP_J;
                        default: ; // stay in current state
                    endcase
                end
            end
        end

        // operator sub-states -> operator sub-states
        //& operator sub-states -> main functions
        S_OP_T, 
        S_OP_A, 
        S_OP_B, 
        S_OP_C, 
        S_OP_J: begin
            if (confirm_flag) begin
                // jump to main functions or menu
                case (menu_sel)
                    3'b000: state_next = S_MENU;
                    3'b001: state_next = S_INPUTER;
                    3'b010: state_next = S_GENERATOR;
                    3'b011: state_next = S_DISPLAYER;
                    3'b100: state_next = S_OPERATOR;
                    3'b101: state_next = S_SETTINGS;
                    default: ; // stay in current state
                endcase

                // jump to operator sub-states
                if (menu_sel == 3'b100) begin
                case (op_sel)
                    3'b000: state_next = S_OP_T;
                    3'b001: state_next = S_OP_A;
                    3'b010: state_next = S_OP_B;
                    3'b011: state_next = S_OP_C;
                    3'b100: state_next = S_OP_J;
                    default: ; // stay in current state
                endcase
                end
            end
        end

        // settings -> settings sub-states, (right)SW4-SW3 + confirm btn
        S_SETTINGS: begin
            if (confirm_flag) begin
                // jump to main functions or menu
                case (menu_sel)
                    3'b000: state_next = S_MENU;
                    3'b001: state_next = S_INPUTER;
                    3'b010: state_next = S_GENERATOR;
                    3'b011: state_next = S_DISPLAYER;
                    3'b100: state_next = S_OPERATOR;
                    3'b101: state_next = S_SETTINGS;
                    default: ; // stay in current state
                endcase

                // jump to settings sub-states
                if (menu_sel == 3'b101) begin
                    case (setting_sel)
                        2'b00: state_next = S_SE_n;
                        2'b01: state_next = S_SE_c;
                        2'b10: state_next = S_SE_r;
                        default: ; // stay in current state
                    endcase
                end
            end
        end

        // settings sub-states -> settings sub-states
        // & settings sub-states -> main functions
        S_SE_n,
        S_SE_c,
        S_SE_r: begin
            if (confirm_flag) begin
                // jump to main functions or menu
                case (menu_sel)
                    3'b000: state_next = S_MENU;
                    3'b001: state_next = S_INPUTER;
                    3'b010: state_next = S_GENERATOR;
                    3'b011: state_next = S_DISPLAYER;
                    3'b100: state_next = S_OPERATOR;
                    3'b101: state_next = S_SETTINGS;
                    default: ; // stay in current state
                endcase

                // jump to settings sub-states
                if (menu_sel == 3'b101) begin
                    case (setting_sel)
                        2'b00: state_next = S_SE_n;
                        2'b01: state_next = S_SE_c;
                        2'b10: state_next = S_SE_r;
                        default: ; // stay in current state
                    endcase
                end
            end
        end
            
    endcase
end

//==========================================================================
// S_SE_n: 矩阵数量限制设置
//==========================================================================
// 真正供给系统的数量限制 (寄存器)
reg [2:0] setting_max_per_dim; 

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // 复位时的默认值4
        setting_max_per_dim <= 3'd2; 
    end else begin
        // 只有在 "S_SE_n" 状态下，且按下 Confirm 时，才更新值
        if (state == S_SE_n && confirm_flag) begin
            // 安全检查：防止用户设置为 0 (这会导致错误)
            if (matrix_limit_input_preview == 3'd0) begin
                setting_max_per_dim <= 3'd1; // 最小设为 1
            end else begin
                setting_max_per_dim <= matrix_limit_input_preview;
            end           
        end
    end
end

//==========================================================================
// 6. UART 模块 (来自 part_lyx)
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

// --- Sub-module UART TX signals ---
wire [7:0] display_tx_data;
wire       display_tx_start;
wire       display_busy;

wire [7:0] summary_tx_data;
wire       summary_tx_start;
wire       summary_busy;

wire [7:0] selector_tx_data;
wire       selector_tx_start;
wire       selector_busy;
wire       selector_done; // Needed for LED/Status

// --- 计算结果展示模块 UART 信号 ---
wire [7:0] result_display_tx_data;
wire       result_display_tx_start;
wire       result_display_busy;
wire       result_display_done;

// --- UART TX Mux (Priority: Convolution > ResultDisplay > Selector > Summary > Display) ---
wire [7:0] tx_data_mux;
wire       tx_start_mux;
wire       tx_busy;

assign tx_data_mux  = conv_busy            ? conv_tx_data            :
                      result_display_busy ? result_display_tx_data :
                      selector_busy       ? selector_tx_data       :
                      summary_busy        ? summary_tx_data        :
                      display_busy        ? display_tx_data        : 8'd0;

assign tx_start_mux = conv_busy            ? conv_tx_start           :
                      result_display_busy ? result_display_tx_start :
                      selector_busy       ? selector_tx_start       :
                      summary_busy        ? summary_tx_start        :
                      display_busy        ? display_tx_start        : 1'b0;

uart_tx #(
    .CLK_FREQ(CLK_FREQ),
    .BAUD_RATE(BAUD_RATE)
) u_uart_tx (
    .clk(clk),
    .rst_n(rst_n),
    .tx_start(tx_start_mux),
    .tx_data(tx_data_mux),
    .tx(uart_tx),
    .tx_busy(tx_busy)
);

//==========================================================================
// 7. 矩阵存储单元实例化 (Matrix Storage Unit)
//==========================================================================
// Storage signals
wire storage_input_error;
wire [PTR_WIDTH:0] storage_mat_count;
wire [2:0] dim_row_A, dim_col_A;
wire [3:0] read_data_A;
wire [4:0] read_addr_A; 
wire [2:0] dim_row_B, dim_col_B;
wire [3:0] read_data_B;
wire [4:0] read_addr_B; 

// 子模块读取请求信号 (来自各个功能模块)
wire [PTR_WIDTH-1:0] display_read_id;
wire [4:0]           display_read_addr;
wire [PTR_WIDTH-1:0] summary_read_id;
wire [PTR_WIDTH-1:0] selector_read_id;
wire [4:0]           selector_read_addr;

// ========== 双运算数选择逻辑 (前向声明) ==========
// 用于需要两个矩阵的运算（加法、矩阵乘）
// 注意：这些寄存器在后面的 always 块中赋值
reg [PTR_WIDTH-1:0] operand_A_id;    // 第一个运算数 ID
reg [PTR_WIDTH-1:0] operand_B_id;    // 第二个运算数 ID
reg operand_A_selected;              // 第一个运算数已选择
reg operand_B_selected;              // 第二个运算数已选择

// 计算模块读取请求 ID
// 使用选择器选中的 ID，如果没有选择则用拨码开关的值
wire [PTR_WIDTH-1:0] calc_read_id_A = operand_A_selected ? operand_A_id : {1'b0, operand1_id};
wire [PTR_WIDTH-1:0] calc_read_id_B = operand_B_selected ? operand_B_id : {1'b0, operand2_id};
wire [4:0]           calc_read_addr_A_out;  // 来自 matrix_calculator
wire [4:0]           calc_read_addr_B_out;  // 来自 matrix_calculator
wire                 calc_busy;             // 来自 matrix_calculator 

// --- 端口 A 多路复用 (Priority: Selector > Summary > Display > Calc/Default) ---
// 注意: calc_read_addr_A_out 将在后面计算模块实例化后才声明为 wire
wire [PTR_WIDTH-1:0] mux_read_id_A;
wire [4:0]           mux_read_addr_A;

// 地址选择：计算模块忙时使用计算模块请求的地址
assign mux_read_addr_A = selector_busy ? selector_read_addr :
                         display_busy  ? display_read_addr  :
                         calc_busy     ? calc_read_addr_A_out : 5'd0;

// ID 选择：确保计算模块忙时使用正确的矩阵 ID
assign mux_read_id_A   = selector_busy ? selector_read_id :
                         summary_busy  ? summary_read_id  :
                         display_busy  ? display_read_id  :
                         calc_busy     ? calc_read_id_A   : 
                         calc_read_id_A;

// --- 端口 B (专供 Calculator)
// 计算模块忙时使用其请求的地址
assign read_addr_B = calc_busy ? calc_read_addr_B_out : 5'd0;

// 实例化用户的存储单元 (Matrix Storage Unit)
// 使用 HARD_MAX 15 和每种规格上限设置
matrix_storage_unit #(
    .HARD_MAX_MATRICES(MAX_MATRICES), 
    .PTR_WIDTH(PTR_WIDTH)
) u_matrix_store (
    .clk            (clk),
    .rst_n          (rst_n),
    .max_per_dim    (setting_max_per_dim), 

    // Control
    .current_state  (state),         
    .confirm_signal (confirm_flag),  

    // Data Input
    .uart_rx_data   (uart_rx_data),
    .uart_rx_done   (uart_rx_done),  

    // Port A (Muxed)
    .read_id_A      (mux_read_id_A), 
    .dim_row_A      (dim_row_A),     
    .dim_col_A      (dim_col_A),     
    .read_addr_A    (mux_read_addr_A),   
    .read_data_A    (read_data_A),   

    // Port B (Operand 2)
    .read_id_B      (calc_read_id_B),   
    .dim_row_B      (dim_row_B),
    .dim_col_B      (dim_col_B),
    .read_addr_B    (read_addr_B),
    .read_data_B    (read_data_B),

    // Feedback
    .input_error    (storage_input_error),
    .mat_count_out  (storage_mat_count)  // 当前存储矩阵总数
);

//==========================================================================
// 8. 矩阵 UART 展示模块实例化 (Matrix UART Display)
//==========================================================================

// --- A. 矩阵内容 UART 展示模块 (Matrix UART Display) ---
// 触发条件: 处于 S_DISPLAYER 状态, 按下 Send 键, 且 sw_right[1]=0 (非摘要模式)
reg display_start_pulse;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) display_start_pulse <= 1'b0;
    else begin
        display_start_pulse <= 1'b0; // 默认为0，形成脉冲
        // 只有在空闲且符合条件时才触发
        if (state == S_DISPLAYER && send_flag && !sw_right[1] && !display_busy && !summary_busy) begin
            display_start_pulse <= 1'b1;
        end
    end
end

// 开关控制: sw_right[0]=1 表示展示所有矩阵
wire display_all_matrices = sw_right[0];

// 数据管道: 将存储单元端口 A 的输出信号引过来
wire [2:0] display_dim_row_in = dim_row_A;
wire [2:0] display_dim_col_in = dim_col_A;
wire [3:0] display_read_data_in = read_data_A;

matrix_uart_display #(
    .PTR_WIDTH(PTR_WIDTH) // 与存储单元参数保持同步 (4位)
) u_matrix_display (
    .clk            (clk),
    .rst_n          (rst_n),
    .start_display  (display_start_pulse),
    .matrix_id      ({1'b0, operand1_id}),       // 初始选中的矩阵ID
    .display_all    (display_all_matrices),
    .mat_count      (storage_mat_count), // 当前存储的矩阵总数
    
    // 连接到存储单元的接口
    .read_id        (display_read_id),   // 输出: 告诉存储单元读哪个ID
    .read_addr      (display_read_addr), // 输出: 告诉存储单元读哪个地址
    .read_data      (display_read_data_in), // 输入: 存储单元返回的数据
    .dim_row        (display_dim_row_in),   // 输入: 存储单元返回的行数
    .dim_col        (display_dim_col_in),   // 输入: 存储单元返回的列数
    
    // UART 接口
    .tx_data        (display_tx_data),
    .tx_start       (display_tx_start),
    .tx_busy        (tx_busy),
    .busy           (display_busy), // 输出忙碌信号
    .done           () // 完成信号悬空 (本模块不需要处理完成信号)
);

// --- B. 矩阵摘要展示模块 ---
// 触发条件: 处于 S_DISPLAYER 状态, 按下 Send 键, 且 sw_right[1]=1 (摘要模式)
reg summary_start_pulse;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) summary_start_pulse <= 1'b0;
    else begin
        summary_start_pulse <= 1'b0;
        if (state == S_DISPLAYER && send_flag && sw_right[1] && !summary_busy && !display_busy) begin
            summary_start_pulse <= 1'b1;
        end
    end
end

matrix_summary_display #(
    .MAX_MATRICES(MAX_MATRICES),
    .PTR_WIDTH(PTR_WIDTH) // 重要: 必须使用 4 位以匹配你的存储设计
) u_matrix_summary (
    .clk            (clk),
    .rst_n          (rst_n),
    .start_display  (summary_start_pulse),
    .mat_count      (storage_mat_count),
    
    // 连接到存储单元的接口 (复用端口 A)
    // 摘要模块只需要读维度(row/col)，不需要读具体数据(read_data)
    .read_id        (summary_read_id),
    .dim_row        (dim_row_A),        
    .dim_col        (dim_col_A),
    
    // UART 接口
    .tx_data        (summary_tx_data),
    .tx_start       (summary_tx_start),
    .tx_busy        (tx_busy),
    .busy           (summary_busy),
    .done           () // 完成信号悬空
);

// --- C. 运算数选择模块  ---
// 触发条件: 处于任何运算子状态 (S_OP_*) 且按下 Send 键
reg selector_start_pulse;
// 判断当前是否处于运算子状态
wire in_op_substate = (state == S_OP_T) || (state == S_OP_A) ||
                      (state == S_OP_B) || (state == S_OP_C) || (state == S_OP_J);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) selector_start_pulse <= 1'b0;
    else begin
        selector_start_pulse <= 1'b0;
        // 只有当 UART 不忙且其他展示模块也不忙时才触发
        if (in_op_substate && send_flag && !selector_busy && !display_busy && !summary_busy) begin
            selector_start_pulse <= 1'b1;
        end
    end
end

wire selector_error;
wire [PTR_WIDTH-1:0] selected_operand_id; // 选择器最终选中的矩阵 ID

// selecting_second 标志（在前面的 always 块中使用）
reg selecting_second;                // 正在选择第二个运算数

// 判断当前运算是否需要两个矩阵
wire needs_two_operands = (state == S_OP_A) || (state == S_OP_C); // 加法、矩阵乘
wire needs_one_operand  = (state == S_OP_T) || (state == S_OP_B); // 转置、标量乘

operand_selector #(
    .MAX_MATRICES(MAX_MATRICES),
    .PTR_WIDTH(PTR_WIDTH) // 重要: 使用 4 位
) u_operand_selector (
    .clk            (clk),
    .rst_n          (rst_n),
    .start          (selector_start_pulse),
    .confirm        (confirm_flag),
    .row_input      (row_input),        // 来自左侧开关 sw_left[5:3] 的行数输入
    .col_input      (col_input),        // 来自左侧开关 sw_left[2:0] 的列数输入
    .matrix_select  (matrix_select),    // 来自左侧开关 sw_left[4:2] 的矩阵选择
    .mat_count      (storage_mat_count),
    
    // 连接到存储单元的接口
    .read_id        (selector_read_id),
    .read_addr      (selector_read_addr),
    .dim_row        (dim_row_A),
    .dim_col        (dim_col_A),
    .read_data      (read_data_A),
    
    // UART 接口
    .tx_data        (selector_tx_data),
    .tx_start       (selector_tx_start),
    .tx_busy        (tx_busy),
    
    // 状态与结果输出
    .busy           (selector_busy),
    .done           (selector_done),    // 用于驱动 LED 或状态机
    .error          (selector_error),
    .selected_id    (selected_operand_id), // 我们只需要这个 ID
    
    // (可选: 接收选中矩阵的行/列。此处为了保持顶层简洁，选择悬空不连接，
    //  因为后续计算可以直接通过 ID 从存储单元获取这些信息)
    .selected_row   (), 
    .selected_col   ()
);

//==========================================================================
// 9. 倒计时模块实例化
//==========================================================================
wire [3:0] countdown_seconds; // 连接到数码管显示逻辑
wire       countdown_active;  // 连接到 led_busy
wire       countdown_timeout; // 如果后续需要处理超时事件(比如自动确认)，可以用这个

// 定义启动信号
// 注意：你需要逻辑来驱动 start_countdown，比如在检测到错误时拉高一个周期
reg        start_countdown;   

countdown_unit #(
    .CLK_FREQ(CLK_FREQ)    // 仿真时可以改为小数值
) u_countdown (
    .clk            (clk),
    .rst_n          (rst_n),
    
    .start          (start_countdown), // 输入：启动脉冲
    .setting_in     (count_down_input),// 输入：来自开关的设置值
    
    .current_seconds(countdown_seconds),// 输出：给 DK7/DK8 显示
    .active         (countdown_active), // 输出：给 LED Busy
    .timeout        (countdown_timeout) // 输出：结束脉冲
);

//==========================================================================
// 10. 运算数选择与验证
//==========================================================================
wire      add_valid, mul_valid;
wire [2:0] mul_res_row, mul_res_col;
// 加法验证器
adder_validator u_add_val (
    .dim_A_row(dim_row_A),    
    .dim_A_col(dim_col_A),
    .dim_B_row(dim_row_B),  
    .dim_B_col(dim_col_B),
    .valid_add(add_valid)
);
// 乘法验证器
multiplexer_validator u_mul_val (
    .dim_A_row(dim_row_A),    
    .dim_A_col(dim_col_A),
    .dim_B_row(dim_row_B),  
    .dim_B_col(dim_col_B),
    .valid_mul(mul_valid),
    .result_row(mul_res_row),
    .result_col(mul_res_col)
);

//==========================================================================
// 11. 倒计时触发控制
//==========================================================================

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        start_countdown <= 1'b0;
        error_flag   <= 1'b0; // 复位内部标志
    end else begin
        start_countdown <= 1'b0;
        
        // 当倒计时结束或返回菜单时，清除运算错误标志
        if (countdown_timeout || state == S_MENU) begin
            error_flag <= 1'b0;
        end
        
        if (confirm_flag) begin
            case (state)
                S_OP_A: begin
                    if (!add_valid) begin
                        start_countdown <= 1'b1;
                        error_flag   <= 1'b1; // 记录运算错误
                    end
                end
                
                S_OP_C: begin
                    if (!mul_valid) begin
                        start_countdown <= 1'b1;
                        error_flag   <= 1'b1; // 记录运算错误
                    end
                end
                default: ; 
            endcase
        end
    end
end

//==========================================================================
// 12. 卷积模块 (Convolution - Bonus)
//==========================================================================

// 卷积控制器信号
wire [35:0] conv_kernel_packed;
reg [3:0] conv_kernel_flat [0:8];
wire conv_start_pulse;
wire [15:0] conv_pixel_out;
wire conv_pixel_valid;
wire conv_done;
wire conv_busy;
wire conv_ctrl_done;
wire [15:0] conv_cycle_count;

// 解包卷积核
always @(*) begin
    conv_kernel_flat[0] = conv_kernel_packed[3:0];
    conv_kernel_flat[1] = conv_kernel_packed[7:4];
    conv_kernel_flat[2] = conv_kernel_packed[11:8];
    conv_kernel_flat[3] = conv_kernel_packed[15:12];
    conv_kernel_flat[4] = conv_kernel_packed[19:16];
    conv_kernel_flat[5] = conv_kernel_packed[23:20];
    conv_kernel_flat[6] = conv_kernel_packed[27:24];
    conv_kernel_flat[7] = conv_kernel_packed[31:28];
    conv_kernel_flat[8] = conv_kernel_packed[35:32];
end

// 卷积启动信号：进入S_OP_J状态时启动输入
reg conv_start_input;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        conv_start_input <= 1'b0;
    end else begin
        conv_start_input <= 1'b0;
        if (state == S_OP_J && state_next != S_OP_J) begin
            // 刚进入S_OP_J状态时启动输入
        end else if (state != S_OP_J && state_next == S_OP_J) begin
            conv_start_input <= 1'b1;
        end
    end
end

// UART TX多路复用信号（卷积输出）
wire [7:0] conv_tx_data;
wire conv_tx_start;

// 卷积控制器实例化
convolution_controller u_conv_ctrl (
    .clk            (clk),
    .rst_n          (rst_n),
    .start_input    (conv_start_input),
    .confirm        (confirm_flag),
    
    // UART RX
    .uart_rx_data   (uart_rx_data),
    .uart_rx_done   (uart_rx_done),
    
    // UART TX
    .tx_data        (conv_tx_data),
    .tx_start       (conv_tx_start),
    .tx_busy        (tx_busy),
    
    // 卷积核和控制（打包格式）
    .kernel_flat_packed(conv_kernel_packed),
    .conv_start     (conv_start_pulse),
    .conv_pixel_out (conv_pixel_out),
    .conv_pixel_valid(conv_pixel_valid),
    .conv_done      (conv_done),
    
    // 状态
    .busy           (conv_busy),
    .done           (conv_ctrl_done),
    .cycle_count    (conv_cycle_count)
);

// 实例化卷积计算模块
convolution u_convolution (
    .clk            (clk),
    .rst_n          (rst_n),
    .start          (conv_start_pulse),
    .kernel_flat    (conv_kernel_flat),
    .pixel_out      (conv_pixel_out),
    .pixel_valid    (conv_pixel_valid),
    .done           (conv_done)
);

//==========================================================================
// 矩阵计算核心 (来自 part_shl) - matrix_calculator 实例化
//==========================================================================

// 操作码推导（根据当前状态自动生成）
wire [2:0] calc_opcode;
assign calc_opcode = (state == S_OP_T) ? 3'b000 :  // 转置
                     (state == S_OP_A) ? 3'b001 :  // 加法
                     (state == S_OP_B) ? 3'b010 :  // 标量乘
                     (state == S_OP_C) ? 3'b011 :  // 矩阵乘
                     3'b000;  // 默认

// 计算模块其他信号 (calc_busy, calc_read_addr_A/B_out 已在前面声明)
wire        calc_done;
wire [2:0]  calc_result_rows;
wire [2:0]  calc_result_cols;
wire [4:0]  result_read_addr;
wire [15:0] result_read_data;

// 计算启动脉冲 & 结果显示启动
reg calc_start_pulse;
reg result_display_start;
reg calc_active; // 记录是否启动过一次计算

// 判断运算数是否已全部选择完成
wire operands_ready = needs_one_operand  ? operand_A_selected : 
                      needs_two_operands ? (operand_A_selected && operand_B_selected) : 1'b0;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        calc_start_pulse <= 1'b0;
        result_display_start <= 1'b0;
        calc_active <= 1'b0;
        operand_A_id <= 0;
        operand_B_id <= 0;
        operand_A_selected <= 1'b0;
        operand_B_selected <= 1'b0;
        selecting_second <= 1'b0;
    end else begin
        calc_start_pulse <= 1'b0;      // 形成单周期脉冲
        result_display_start <= 1'b0;  // 形成单周期脉冲

        // 当 operand_selector 完成选择时，保存选中的 ID
        if (selector_done) begin
            if (needs_one_operand) begin
                // 单运算数运算：直接保存到 A
                operand_A_id <= selected_operand_id;
                operand_A_selected <= 1'b1;
            end else if (needs_two_operands) begin
                // 双运算数运算：先保存 A，再保存 B
                if (!operand_A_selected) begin
                    operand_A_id <= selected_operand_id;
                    operand_A_selected <= 1'b1;
                    selecting_second <= 1'b1; // 标记需要选第二个
                end else begin
                    operand_B_id <= selected_operand_id;
                    operand_B_selected <= 1'b1;
                    selecting_second <= 1'b0;
                end
            end
        end

        // 离开运算子状态时，清除所有选择状态
        if (!in_op_substate) begin
            operand_A_selected <= 1'b0;
            operand_B_selected <= 1'b0;
            selecting_second <= 1'b0;
        end

        // 计算完成且确实启动过计算时，自动显示结果
        // 关键：必须确保 selector 不忙（避免在维度选择时误触发）
        if (calc_active && calc_done && in_op_substate && !result_display_busy && !selector_busy) begin
            result_display_start <= 1'b1;
            calc_active <= 1'b0; // 本次显示后清除标记
        end

        // 结果显示完成后，清除选择状态以便下次选择
        if (result_display_done) begin
            operand_A_selected <= 1'b0;
            operand_B_selected <= 1'b0;
        end

        // 在运算子状态下按确认键，且其他模块不忙时，检查验证后启动计算
        // 关键修复：只有在运算数已全部选择完成后才能启动计算
        // selector_busy 时或 operands_ready 为 0 时不能启动计算
        if (in_op_substate && confirm_flag && operands_ready && !selector_busy && !display_busy && !summary_busy && !result_display_busy && !calc_busy) begin
            case (state)
                S_OP_T: begin
                    calc_start_pulse <= 1'b1;              // 转置：无需验证
                    calc_active      <= 1'b1;
                    // 注意：不要在这里清除 operand_A_selected，否则 calc_read_id_A 会变
                end
                S_OP_A: if (add_valid) begin
                    calc_start_pulse <= 1'b1;              // 加法：需通过验证
                    calc_active      <= 1'b1;
                    // 注意：计算期间需要保持 ID 不变
                end
                S_OP_B: begin
                    calc_start_pulse <= 1'b1;              // 标量乘：无需验证
                    calc_active      <= 1'b1;
                end
                S_OP_C: if (mul_valid) begin
                    calc_start_pulse <= 1'b1;              // 矩阵乘：需通过验证
                    calc_active      <= 1'b1;
                end
                default: ;
            endcase
        end

        // 离开运算子状态时清除 calc_active
        if (!in_op_substate) begin
            calc_active <= 1'b0;
        end
    end
end

// 矩阵计算器实例化
matrix_calculator #(
    .MAX_DIM(5),
    .DATA_WIDTH(4),
    .RESULT_WIDTH(16)
) u_matrix_calculator (
    .clk            (clk),
    .rst_n          (rst_n),
    
    // 控制接口
    .start          (calc_start_pulse),
    .opcode         (calc_opcode),
    .scalar         (scalar_input[3:0]),  // 标量乘法使用的标量值
    
    // 矩阵 A 接口（来自存储单元端口 A）
    .dim_row_A      (dim_row_A),
    .dim_col_A      (dim_col_A),
    .read_addr_A    (calc_read_addr_A_out),
    .read_data_A    (read_data_A),
    
    // 矩阵 B 接口（来自存储单元端口 B）
    .dim_row_B      (dim_row_B),
    .dim_col_B      (dim_col_B),
    .read_addr_B    (calc_read_addr_B_out),
    .read_data_B    (read_data_B),
    
    // 结果输出接口
    .busy           (calc_busy),
    .done           (calc_done),
    .result_rows    (calc_result_rows),
    .result_cols    (calc_result_cols),
    
    // 结果读取接口
    .result_read_addr  (result_read_addr),
    .result_read_data  (result_read_data)
);

// 计算结果 UART 展示模块实例化
calc_result_display #(
    .MAX_DIM(5),
    .RESULT_WIDTH(16)
) u_calc_result_display (
    .clk            (clk),
    .rst_n          (rst_n),
    
    // 控制接口
    .start_display  (result_display_start),
    .result_rows    (calc_result_rows),
    .result_cols    (calc_result_cols),
    .op_type        (calc_opcode),
    
    // 结果数据接口
    .result_read_addr (result_read_addr),
    .read_data      (result_read_data),
    
    // UART TX 接口
    .tx_data        (result_display_tx_data),
    .tx_start       (result_display_tx_start),
    .tx_busy        (tx_busy),
    
    // 状态输出
    .busy           (result_display_busy),
    .done           (result_display_done)
);


//==========================================================================
// LED logic
//==========================================================================
assign led_error = error_flag | storage_input_error | selector_error;
assign led_idle  = (state == S_MENU);
assign led_busy  = countdown_active || selector_busy || calc_busy || result_display_busy || conv_busy || (state >= S_OP_T && state <= S_OP_J);
assign led_done  = calc_done || selector_done || result_display_done || conv_ctrl_done;

// UART work indicators
always @(*) begin
    LED1_uart_tx = uart_tx_work;
    LED0_uart_rx = uart_rx_work;
end


//======================================================================
// 5. Seven-segment display definitions
//======================================================================
localparam SEG_M = 8'b1000_0000; //use a dot to represent 'M' for Menu
localparam SEG_I = 8'b0000_0110;
localparam SEG_G = 8'b0011_1101;
localparam SEG_D = 8'b0101_1110;
localparam SEG_O = 8'b0011_1111;
localparam SEG_S = 8'b0110_1101;

localparam SEG_0 = 8'b0011_1111;
localparam SEG_1 = 8'b0000_0110;
localparam SEG_2 = 8'b0101_1011;
localparam SEG_3 = 8'b0100_1111;
localparam SEG_4 = 8'b0110_0110;
localparam SEG_5 = 8'b0110_1101;
localparam SEG_6 = 8'b0111_1101;
localparam SEG_7 = 8'b0000_0111;
localparam SEG_8 = 8'b0111_1111;
localparam SEG_9 = 8'b0110_1111;

localparam SEG_T = 8'b0111_1000;
localparam SEG_A = 8'b0111_0111;
localparam SEG_B = 8'b0111_1100;
localparam SEG_C = 8'b0011_1001;
localparam SEG_J = 8'b0000_1101;

localparam SEG_n = 8'b0101_0100;
localparam SEG_c = 8'b0101_1000;
localparam SEG_r = 8'b0101_0000;

localparam SEG_BLANK = 8'b0000_0000;

//----------------------------------------------------------------------
// DK1 & DK4 
//----------------------------------------------------------------------
reg [7:0] dk1_value, dk4_value;

// dk1: Main function indicator
always @(*) begin
    case (state)
        S_MENU:          dk1_value = SEG_M;
        S_INPUTER:       dk1_value = SEG_I;
        S_GENERATOR:     dk1_value = SEG_G;
        S_DISPLAYER:     dk1_value = SEG_D;
        S_OPERATOR,
        S_OP_T, S_OP_A, 
        S_OP_B, S_OP_C, 
        S_OP_J:          dk1_value = SEG_O;
        S_SETTINGS,
        S_SE_n, S_SE_c, 
        S_SE_r:          dk1_value = SEG_S;
        default:         dk1_value = SEG_BLANK;
    endcase
end

// dk4: Operator & settings sub-function indicator
always @(*) begin
    dk4_value = SEG_BLANK;
    case (state)
        S_OPERATOR: begin
            case(op_sel)
                3'b000:  dk4_value = SEG_T;
                3'b001:  dk4_value = SEG_A;
                3'b010:  dk4_value = SEG_B;
                3'b011:  dk4_value = SEG_C;
                3'b100:  dk4_value = SEG_J;
                default: dk4_value = SEG_BLANK;
            endcase
        end
        S_OP_T:  dk4_value = SEG_T;
        S_OP_A:  dk4_value = SEG_A;
        S_OP_B:  dk4_value = SEG_B;
        S_OP_C:  dk4_value = SEG_C;
        S_OP_J:  dk4_value = SEG_J;
        
        // Settings
        S_SETTINGS: begin
            case(setting_sel)
                2'b00:   dk4_value = SEG_n;
                2'b01:   dk4_value = SEG_c;
                2'b10:   dk4_value = SEG_r;
                default: dk4_value = SEG_BLANK;
            endcase
        end
        S_SE_n:  dk4_value = SEG_n;
        S_SE_c:  dk4_value = SEG_c;
        S_SE_r:  dk4_value = SEG_r;
        default: dk4_value = SEG_BLANK;
    endcase
end

//----------------------------------------------------------------------
// 2. DK7 & DK8
//----------------------------------------------------------------------
reg [7:0] dk7_value, dk8_value;

// 辅助逻辑：将倒计时数值转换为段码
reg [7:0] countdown_seg;
always @(*) begin
    case (countdown_seconds)
        4'd0: countdown_seg = SEG_0;
        4'd1: countdown_seg = SEG_1;
        4'd2: countdown_seg = SEG_2;
        4'd3: countdown_seg = SEG_3;
        4'd4: countdown_seg = SEG_4;
        4'd5: countdown_seg = SEG_5;
        4'd6: countdown_seg = SEG_6;
        4'd7: countdown_seg = SEG_7;
        4'd8: countdown_seg = SEG_8;
        4'd9: countdown_seg = SEG_9;
        default: countdown_seg = SEG_BLANK;
    endcase
end

// 辅助逻辑：将矩阵数量转换为段码
reg [7:0] limit_seg;
reg [2:0] limit_num_to_show; // 暂存要显示的数字
always @(*) begin
    if (state == S_SE_n) begin
        // 如果在S_SE_n，显示开关的实时预览值
        limit_num_to_show = {1'b0, matrix_limit_input_preview}; 
    end else begin
        limit_num_to_show = setting_max_per_dim; 
    end
    case (limit_num_to_show)
        3'd1: limit_seg = SEG_1;
        3'd2: limit_seg = SEG_2;
        3'd3: limit_seg = SEG_3;
        3'd4: limit_seg = SEG_4;
        3'd5: limit_seg = SEG_5;
        3'd6: limit_seg = SEG_6;
        3'd7: limit_seg = SEG_7;
        default: limit_seg = SEG_BLANK;
    endcase
end

// 辅助逻辑：将卷积周期数转换为4位BCD段码（支持0-9999）
reg [3:0] conv_cycles_digit [0:3]; // 千、百、十、个位
always @(*) begin
    conv_cycles_digit[3] = (conv_cycle_count / 1000) % 10;  // 千位
    conv_cycles_digit[2] = (conv_cycle_count / 100) % 10;   // 百位
    conv_cycles_digit[1] = (conv_cycle_count / 10) % 10;    // 十位
    conv_cycles_digit[0] = conv_cycle_count % 10;           // 个位
end

// 将数字转换为段码的函数
function [7:0] digit_to_seg;
    input [3:0] digit;
    begin
        case (digit)
            4'd0: digit_to_seg = SEG_0;
            4'd1: digit_to_seg = SEG_1;
            4'd2: digit_to_seg = SEG_2;
            4'd3: digit_to_seg = SEG_3;
            4'd4: digit_to_seg = SEG_4;
            4'd5: digit_to_seg = SEG_5;
            4'd6: digit_to_seg = SEG_6;
            4'd7: digit_to_seg = SEG_7;
            4'd8: digit_to_seg = SEG_8;
            4'd9: digit_to_seg = SEG_9;
            default: digit_to_seg = SEG_BLANK;
        endcase
    end
endfunction

// dk7/dk8 赋值逻辑
always @(*) begin
    dk7_value = SEG_BLANK;
    dk8_value = SEG_BLANK;

    // 优先级1: 卷积完成后显示周期数（DK7=百位+十位, DK8=个位，简化显示）
    if (state == S_OP_J && conv_ctrl_done) begin
        // 显示后3位数字（最多999）
        if (conv_cycle_count < 100) begin
            dk7_value = digit_to_seg(conv_cycles_digit[1]); // 十位
            dk8_value = digit_to_seg(conv_cycles_digit[0]); // 个位
        end else begin
            dk7_value = digit_to_seg(conv_cycles_digit[2]); // 百位
            dk8_value = digit_to_seg(conv_cycles_digit[1]); // 十位（简化，只显示2位）
        end
    end
    // 优先级2: 当处于 Operator 模式且可能触发错误时显示倒计时
    else if (state == S_OPERATOR || state == S_OP_T || state == S_OP_A || 
        state == S_OP_B || state == S_OP_C || state == S_OP_J) begin
        
        dk8_value = countdown_seg; // 个位显示在最右侧 dk8
        dk7_value = SEG_BLANK;     // 十位保持黑屏 (如果倒计时大于9需要修改此处)
    end
    // 优先级3: 矩阵数量设置显示
    else if (state == S_SE_n) begin
        dk7_value = limit_seg;    
        dk8_value = SEG_BLANK;    
    end
end

//======================================================================
// 7. seg_scan instance 
//======================================================================
// 处理 DK1 & DK4 是否显示的逻辑 (Operator/Settings模式下显示)
wire in_operator_or_settings_mode =
       (state == S_OPERATOR) || (state == S_OP_T) || (state == S_OP_A) || (state == S_OP_B) || (state == S_OP_C) || (state == S_OP_J) ||
       (state == S_SETTINGS) || (state == S_SE_n) || (state == S_SE_c) || (state == S_SE_r);

wire [7:0] display_dk4_value = in_operator_or_settings_mode ? dk4_value : SEG_BLANK;

// 定义扫描输出信号
wire [7:0] seg0_scan_out;
wire       dk1_en_scan;
wire       dk4_en_scan;

wire [7:0] seg1_scan_out;
wire       dk7_en_scan;
wire       dk8_en_scan;

// 控制 Seg0 总线 (DK1, DK4)
seg_scan u_seg_scan_0 (
    .clk    (clk),
    .rst_n  (rst_n),
    .val_a  (dk1_value),          
    .val_b  (display_dk4_value),  
    .seg    (seg0_scan_out),          
    .en_a   (dk1_en_scan),        
    .en_b   (dk4_en_scan)         
);

// 控制 Seg1 总线 (DK7, DK8)
seg_scan u_seg_scan_1 (
    .clk    (clk),
    .rst_n  (rst_n),
    .val_a  (dk7_value),  // 对应原来的 val_a 位置 (DK7)
    .val_b  (dk8_value),  // 对应原来的 val_b 位置 (DK8)
    .seg    (seg1_scan_out),
    .en_a   (dk7_en_scan), // 控制 DK7
    .en_b   (dk8_en_scan)  // 控制 DK8
);

//----------------------------------------------------------------------
// 4. 最终端口映射
//----------------------------------------------------------------------
always @(*) begin
    // ------------- DK1-DK4 (seg0 bus) -----------------
    seg0   = seg0_scan_out;
    dk1_en = dk1_en_scan;
    dk4_en = dk4_en_scan;

    // ------------- DK5-DK8 (seg1 bus) -----------------
    seg1   = seg1_scan_out;
    dk7_en = dk7_en_scan;
    dk8_en = dk8_en_scan;
end

endmodule