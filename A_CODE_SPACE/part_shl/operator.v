//==============================================================================
// operator.v
// 运算主控模块
// 功能：实现完整的矩阵运算控制流程
// 流程：选择运算类型 → 显示矩阵信息 → 选择运算数 → 验证 → 倒计时/计算 → 显示结果
//==============================================================================
module operator #(
    parameter CLK_FREQ     = 100_000_000,  // 100MHz时钟
    parameter MAX_MATRICES = 4,             // 最大矩阵数量
    parameter MAX_DIM      = 5,             // 最大维度
    parameter DATA_WIDTH   = 4,             // 元素位宽
    parameter ELEM_COUNT   = 25             // 5x5 = 25元素
)(
    input  wire        clk,
    input  wire        rst_n,
    
    //--------------------------------------------------------------------------
    // 矩阵存储接口
    //--------------------------------------------------------------------------
    input  wire [2:0]  mat_count,                                   // 已存储矩阵数量
    input  wire [2:0]  mat_rows [0:MAX_MATRICES-1],                // 各矩阵行数
    input  wire [2:0]  mat_cols [0:MAX_MATRICES-1],                // 各矩阵列数
    input  wire [DATA_WIDTH*ELEM_COUNT-1:0] mat_data [0:MAX_MATRICES-1], // 矩阵数据
    
    //--------------------------------------------------------------------------
    // 用户输入接口
    //--------------------------------------------------------------------------
    input  wire        op_start,           // 开始运算流程
    input  wire [2:0]  op_type,            // 运算类型: 000=转置, 001=加法, 010=数乘, 011=乘法, 100=卷积
    input  wire [1:0]  operand1_sel,       // 操作数1选择 (矩阵索引 0-3)
    input  wire [1:0]  operand2_sel,       // 操作数2选择 (矩阵索引 0-3 或 标量)
    input  wire [3:0]  scalar_val,         // 数乘标量值
    input  wire        manual_mode,        // 1=手动选择, 0=随机选择
    input  wire        confirm,            // 确认选择
    input  wire [3:0]  countdown_set,      // 倒计时设置 (5-15秒)
    
    //--------------------------------------------------------------------------
    // 状态输出
    //--------------------------------------------------------------------------
    output reg  [3:0]  current_state,      // 当前状态(用于外部显示)
    output reg         valid_operands,     // 操作数合法
    output reg         calc_busy,          // 计算中
    output reg         calc_done,          // 计算完成
    output reg         error_flag,         // 错误标志
    
    //--------------------------------------------------------------------------
    // 倒计时输出
    //--------------------------------------------------------------------------
    output wire [3:0]  countdown_val,      // 当前倒计时值(秒)
    output wire        timeout_flag,       // 超时标志
    
    //--------------------------------------------------------------------------
    // 计算结果输出
    //--------------------------------------------------------------------------
    output reg  [2:0]  result_rows,        // 结果矩阵行数
    output reg  [2:0]  result_cols,        // 结果矩阵列数
    output reg  [15:0] result_data [0:ELEM_COUNT-1], // 结果数据(16位以支持乘法结果)
    
    //--------------------------------------------------------------------------
    // 七段显示输出
    //--------------------------------------------------------------------------
    output reg  [3:0]  seg_op_type,        // 运算类型显示
    output reg  [3:0]  seg_countdown       // 倒计时显示
);

    //--------------------------------------------------------------------------
    // 运算类型常量
    //--------------------------------------------------------------------------
    localparam OP_TRANSPOSE = 3'b000;   // T - 转置
    localparam OP_ADD       = 3'b001;   // A - 加法
    localparam OP_SCALAR    = 3'b010;   // B - 数乘
    localparam OP_MULTIPLY  = 3'b011;   // C - 矩阵乘法
    localparam OP_CONVOLVE  = 3'b100;   // J - 卷积
    
    //--------------------------------------------------------------------------
    // 状态定义
    //--------------------------------------------------------------------------
    localparam ST_IDLE          = 4'd0;   // 空闲
    localparam ST_SELECT_TYPE   = 4'd1;   // 选择运算类型
    localparam ST_SHOW_INFO     = 4'd2;   // 显示矩阵信息
    localparam ST_SELECT_OP1    = 4'd3;   // 选择操作数1
    localparam ST_SELECT_OP2    = 4'd4;   // 选择操作数2
    localparam ST_VALIDATE      = 4'd5;   // 验证操作数
    localparam ST_COUNTDOWN     = 4'd6;   // 倒计时(操作数不合法时)
    localparam ST_CALCULATE     = 4'd7;   // 执行计算
    localparam ST_SHOW_RESULT   = 4'd8;   // 显示结果
    localparam ST_ERROR         = 4'd9;   // 错误状态
    
    reg [3:0] state, next_state;
    
    //--------------------------------------------------------------------------
    // 内部信号
    //--------------------------------------------------------------------------
    reg [2:0]  saved_op_type;
    reg [1:0]  saved_op1_idx;
    reg [1:0]  saved_op2_idx;
    reg [3:0]  saved_scalar;
    
    // 验证器信号
    wire       add_valid;
    wire       mul_valid;
    wire [2:0] mul_result_row, mul_result_col;
    wire       conv_valid;
    wire [2:0] conv_result_row, conv_result_col;
    
    // 倒计时信号
    reg        timer_start;
    reg        timer_reset;
    reg [3:0]  timer_seconds;
    
    // 计算控制
    reg        calc_start;
    reg [4:0]  calc_idx;
    
    // 随机数生成 (简化LFSR)
    reg [7:0]  lfsr;
    wire [1:0] rand_op1 = lfsr[1:0] % mat_count;
    wire [1:0] rand_op2 = lfsr[3:2] % mat_count;
    wire [3:0] rand_scalar = lfsr[7:4];
    
    //--------------------------------------------------------------------------
    // 实例化验证器
    //--------------------------------------------------------------------------
    adder_validator adder_val_inst (
        .a_row(mat_rows[saved_op1_idx]),
        .a_col(mat_cols[saved_op1_idx]),
        .b_row(mat_rows[saved_op2_idx]),
        .b_col(mat_cols[saved_op2_idx]),
        .valid_add(add_valid)
    );
    
    multiplexer_validator mul_val_inst (
        .a_row(mat_rows[saved_op1_idx]),
        .a_col(mat_cols[saved_op1_idx]),
        .b_row(mat_rows[saved_op2_idx]),
        .b_col(mat_cols[saved_op2_idx]),
        .valid_mul(mul_valid),
        .result_row(mul_result_row),
        .result_col(mul_result_col)
    );
    
    convoluter_validator conv_val_inst (
        .image_row(mat_rows[saved_op1_idx]),
        .image_col(mat_cols[saved_op1_idx]),
        .kernel_row(mat_rows[saved_op2_idx]),
        .kernel_col(mat_cols[saved_op2_idx]),
        .valid_conv(conv_valid),
        .output_row(conv_result_row),
        .output_col(conv_result_col)
    );
    
    //--------------------------------------------------------------------------
    // 实例化倒计时器
    //--------------------------------------------------------------------------
    timer #(
        .CLK_FREQ(CLK_FREQ)
    ) timer_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(timer_start),
        .reset(timer_reset),
        .set_seconds(timer_seconds),
        .timeout_flag(timeout_flag),
        .current_seconds(countdown_val)
    );
    
    //--------------------------------------------------------------------------
    // LFSR随机数生成
    //--------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr <= 8'hA5; // 初始种子
        end else begin
            // x^8 + x^6 + x^5 + x^4 + 1
            lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
        end
    end
    
    //--------------------------------------------------------------------------
    // 状态寄存器
    //--------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    //--------------------------------------------------------------------------
    // 状态转移逻辑
    //--------------------------------------------------------------------------
    always @(*) begin
        next_state = state;
        
        case (state)
            ST_IDLE: begin
                if (op_start) begin
                    next_state = ST_SELECT_TYPE;
                end
            end
            
            ST_SELECT_TYPE: begin
                if (confirm) begin
                    next_state = ST_SHOW_INFO;
                end
            end
            
            ST_SHOW_INFO: begin
                if (confirm) begin
                    next_state = ST_SELECT_OP1;
                end
            end
            
            ST_SELECT_OP1: begin
                if (confirm) begin
                    // 转置只需要一个操作数
                    if (saved_op_type == OP_TRANSPOSE) begin
                        next_state = ST_VALIDATE;
                    end else begin
                        next_state = ST_SELECT_OP2;
                    end
                end
            end
            
            ST_SELECT_OP2: begin
                if (confirm) begin
                    next_state = ST_VALIDATE;
                end
            end
            
            ST_VALIDATE: begin
                if (valid_operands) begin
                    next_state = ST_CALCULATE;
                end else begin
                    next_state = ST_COUNTDOWN;
                end
            end
            
            ST_COUNTDOWN: begin
                if (timeout_flag) begin
                    // 超时，随机重新选择
                    next_state = ST_SELECT_OP1;
                end else if (confirm && valid_operands) begin
                    // 用户重新选择了合法操作数
                    next_state = ST_CALCULATE;
                end
            end
            
            ST_CALCULATE: begin
                if (calc_done) begin
                    next_state = ST_SHOW_RESULT;
                end
            end
            
            ST_SHOW_RESULT: begin
                if (confirm) begin
                    next_state = ST_IDLE;
                end
            end
            
            ST_ERROR: begin
                if (confirm) begin
                    next_state = ST_IDLE;
                end
            end
            
            default: next_state = ST_IDLE;
        endcase
    end
    
    //--------------------------------------------------------------------------
    // 状态输出和控制逻辑
    //--------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state   <= ST_IDLE;
            valid_operands  <= 1'b0;
            calc_busy       <= 1'b0;
            calc_done       <= 1'b0;
            error_flag      <= 1'b0;
            result_rows     <= 3'd0;
            result_cols     <= 3'd0;
            saved_op_type   <= 3'd0;
            saved_op1_idx   <= 2'd0;
            saved_op2_idx   <= 2'd0;
            saved_scalar    <= 4'd0;
            timer_start     <= 1'b0;
            timer_reset     <= 1'b1;
            timer_seconds   <= 4'd10;
            calc_start      <= 1'b0;
            calc_idx        <= 5'd0;
            seg_op_type     <= 4'd0;
            seg_countdown   <= 4'd0;
        end else begin
            current_state <= state;
            timer_start   <= 1'b0;
            timer_reset   <= 1'b0;
            calc_start    <= 1'b0;
            
            case (state)
                ST_IDLE: begin
                    calc_busy  <= 1'b0;
                    calc_done  <= 1'b0;
                    error_flag <= 1'b0;
                    timer_reset <= 1'b1;
                end
                
                ST_SELECT_TYPE: begin
                    saved_op_type <= op_type;
                    seg_op_type   <= {1'b0, op_type};
                    timer_seconds <= (countdown_set >= 4'd5 && countdown_set <= 4'd15) ? 
                                     countdown_set : 4'd10;
                end
                
                ST_SELECT_OP1: begin
                    if (confirm) begin
                        if (manual_mode) begin
                            saved_op1_idx <= operand1_sel;
                        end else begin
                            saved_op1_idx <= rand_op1;
                        end
                    end
                end
                
                ST_SELECT_OP2: begin
                    if (confirm) begin
                        if (manual_mode) begin
                            saved_op2_idx <= operand2_sel;
                            saved_scalar  <= scalar_val;
                        end else begin
                            saved_op2_idx <= rand_op2;
                            saved_scalar  <= rand_scalar;
                        end
                    end
                end
                
                ST_VALIDATE: begin
                    // 根据运算类型检查合法性
                    case (saved_op_type)
                        OP_TRANSPOSE: begin
                            // 转置始终合法
                            valid_operands <= 1'b1;
                            result_rows    <= mat_cols[saved_op1_idx];
                            result_cols    <= mat_rows[saved_op1_idx];
                        end
                        
                        OP_ADD: begin
                            valid_operands <= add_valid;
                            if (add_valid) begin
                                result_rows <= mat_rows[saved_op1_idx];
                                result_cols <= mat_cols[saved_op1_idx];
                            end
                        end
                        
                        OP_SCALAR: begin
                            // 数乘始终合法
                            valid_operands <= 1'b1;
                            result_rows    <= mat_rows[saved_op1_idx];
                            result_cols    <= mat_cols[saved_op1_idx];
                        end
                        
                        OP_MULTIPLY: begin
                            valid_operands <= mul_valid;
                            if (mul_valid) begin
                                result_rows <= mul_result_row;
                                result_cols <= mul_result_col;
                            end
                        end
                        
                        OP_CONVOLVE: begin
                            valid_operands <= conv_valid;
                            if (conv_valid) begin
                                result_rows <= conv_result_row;
                                result_cols <= conv_result_col;
                            end
                        end
                        
                        default: valid_operands <= 1'b0;
                    endcase
                end
                
                ST_COUNTDOWN: begin
                    if (state != next_state && next_state == ST_COUNTDOWN) begin
                        // 刚进入倒计时状态
                        timer_start <= 1'b1;
                    end
                    seg_countdown <= countdown_val;
                    
                    // 倒计时期间允许重新选择
                    if (manual_mode) begin
                        saved_op1_idx <= operand1_sel;
                        saved_op2_idx <= operand2_sel;
                        saved_scalar  <= scalar_val;
                    end
                end
                
                ST_CALCULATE: begin
                    calc_busy <= 1'b1;
                    
                    if (!calc_start) begin
                        calc_start <= 1'b1;
                        calc_idx   <= 5'd0;
                    end else begin
                        // 执行计算（简化版本，实际需要多周期）
                        if (calc_idx < result_rows * result_cols) begin
                            calc_idx <= calc_idx + 1;
                            
                            // 具体计算逻辑由外部计算模块实现
                            // 这里只是状态控制
                        end else begin
                            calc_done <= 1'b1;
                            calc_busy <= 1'b0;
                        end
                    end
                end
                
                ST_SHOW_RESULT: begin
                    // 结果保持，等待用户确认
                end
                
                ST_ERROR: begin
                    error_flag <= 1'b1;
                end
            endcase
        end
    end

endmodule
