//==============================================================================
// operand_selector.v
// 运算数手动选择控制器
// 
// 功能：实现用户手动选择运算数的完整交互流程
//
// 交互流程：
// 1. 用户输入行数m，按确认键
// 2. 用户输入列数n，按确认键
// 3. 系统通过UART显示所有m×n矩阵及其编号和内容
// 4. 用户输入矩阵编号，按确认键选定运算数
// 5. 系统显示选定的矩阵
//
// 选择模式：
// - 单矩阵模式：转置、卷积（只选1次）
// - 双矩阵模式：加法、乘法（选2次）
// - 矩阵+标量模式：标量乘法（选1次矩阵 + 拨码开关输入标量）
//==============================================================================
module operand_selector #(
    parameter MAX_MATRICES = 4,
    parameter MAX_DIM      = 5
)(
    input  wire        clk,
    input  wire        rst_n,
    
    //--------------------------------------------------------------------------
    // 矩阵存储接口
    //--------------------------------------------------------------------------
    input  wire [2:0]  mat_count,                              // 已存储矩阵数量
    input  wire [2:0]  mat_rows [0:MAX_MATRICES-1],           // 各矩阵行数
    input  wire [2:0]  mat_cols [0:MAX_MATRICES-1],           // 各矩阵列数
    input  wire [3:0]  mat_data [0:MAX_MATRICES-1][0:24],     // 矩阵数据
    
    //--------------------------------------------------------------------------
    // 用户输入接口
    //--------------------------------------------------------------------------
    input  wire        btn_confirm,        // 确认按钮 (消抖后)
    input  wire [2:0]  sw_dim_input,       // 维度/编号输入 (拨码开关, 1-5)
    input  wire [3:0]  sw_scalar,          // 标量输入 (拨码开关)
    
    //--------------------------------------------------------------------------
    // 运算类型
    //--------------------------------------------------------------------------
    input  wire [2:0]  op_type,            // 000=转置, 001=加法, 010=数乘, 011=乘法, 100=卷积
    
    //--------------------------------------------------------------------------
    // 控制信号
    //--------------------------------------------------------------------------
    input  wire        start,              // 开始选择流程
    output reg         done,               // 选择完成
    output reg         busy,               // 正在选择中
    output reg         error,              // 错误（如找不到匹配矩阵）
    
    //--------------------------------------------------------------------------
    // 选择结果
    //--------------------------------------------------------------------------
    output reg  [1:0]  selected_op1,       // 选定的操作数1索引 (0-3)
    output reg  [1:0]  selected_op2,       // 选定的操作数2索引 (0-3)
    output reg  [3:0]  selected_scalar,    // 选定的标量值
    output reg         op1_valid,          // 操作数1有效
    output reg         op2_valid,          // 操作数2有效
    
    //--------------------------------------------------------------------------
    // UART发送接口
    //--------------------------------------------------------------------------
    output reg  [7:0]  tx_data,            // 发送数据
    output reg         tx_start,           // 发送请求
    input  wire        tx_busy,            // 发送忙信号
    
    //--------------------------------------------------------------------------
    // 七段数码管显示
    //--------------------------------------------------------------------------
    output reg  [3:0]  seg_display_val     // 当前显示值 (用于数码管)
);

    //--------------------------------------------------------------------------
    // 运算类型常量
    //--------------------------------------------------------------------------
    localparam OP_TRANSPOSE = 3'b000;   // 转置 - 单矩阵
    localparam OP_ADD       = 3'b001;   // 加法 - 双矩阵
    localparam OP_SCALAR    = 3'b010;   // 数乘 - 矩阵+标量
    localparam OP_MULTIPLY  = 3'b011;   // 乘法 - 双矩阵
    localparam OP_CONVOLVE  = 3'b100;   // 卷积 - 单矩阵(作为卷积核)

    //--------------------------------------------------------------------------
    // 状态定义
    //--------------------------------------------------------------------------
    localparam ST_IDLE           = 4'd0;
    localparam ST_INPUT_ROW      = 4'd1;   // 等待用户输入行数
    localparam ST_INPUT_COL      = 4'd2;   // 等待用户输入列数
    localparam ST_SHOW_MATRICES  = 4'd3;   // 显示匹配的矩阵
    localparam ST_INPUT_SELECT   = 4'd4;   // 等待用户选择编号
    localparam ST_SHOW_SELECTED  = 4'd5;   // 显示选定的矩阵
    localparam ST_INPUT_SCALAR   = 4'd6;   // 等待标量输入 (数乘专用)
    localparam ST_NEXT_OPERAND   = 4'd7;   // 准备选择下一个操作数
    localparam ST_FINISH         = 4'd8;   // 完成
    localparam ST_ERROR          = 4'd9;   // 错误
    
    reg [3:0] state;
    reg [2:0] query_row, query_col;        // 用户输入的维度
    reg [1:0] operand_num;                 // 当前选择第几个操作数 (0或1)
    reg       needs_second_operand;        // 是否需要第二个操作数
    reg       needs_scalar;                // 是否需要标量
    
    // 确认按钮边沿检测
    reg btn_confirm_d;
    wire btn_confirm_posedge = btn_confirm && !btn_confirm_d;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) btn_confirm_d <= 1'b0;
        else btn_confirm_d <= btn_confirm;
    end
    
    //--------------------------------------------------------------------------
    // 维度显示器实例化
    //--------------------------------------------------------------------------
    wire        dim_disp_done;
    wire        dim_disp_busy;
    wire [2:0]  dim_match_count;
    wire [MAX_MATRICES-1:0] dim_match_mask;
    wire [7:0]  dim_tx_data;
    wire        dim_tx_start;
    reg         dim_disp_start;
    
    dimension_displayer #(
        .MAX_MATRICES(MAX_MATRICES)
    ) u_dim_displayer (
        .clk(clk),
        .rst_n(rst_n),
        .mat_count(mat_count),
        .mat_rows(mat_rows),
        .mat_cols(mat_cols),
        .mat_data(mat_data),
        .query_row(query_row),
        .query_col(query_col),
        .start(dim_disp_start),
        .done(dim_disp_done),
        .busy(dim_disp_busy),
        .match_count(dim_match_count),
        .match_mask(dim_match_mask),
        .tx_data(dim_tx_data),
        .tx_start(dim_tx_start),
        .tx_busy(tx_busy)
    );
    
    //--------------------------------------------------------------------------
    // 单矩阵显示器 (显示选定的矩阵)
    //--------------------------------------------------------------------------
    reg        single_disp_start;
    reg [1:0]  single_disp_idx;
    reg [3:0]  single_state;
    reg [2:0]  single_row, single_col;
    wire       single_disp_done;
    
    localparam SINGLE_IDLE     = 4'd0;
    localparam SINGLE_ELEMENT  = 4'd1;
    localparam SINGLE_SPACE    = 4'd2;
    localparam SINGLE_NEWLINE  = 4'd3;
    localparam SINGLE_DONE     = 4'd4;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            single_state <= SINGLE_IDLE;
            single_row   <= 3'd0;
            single_col   <= 3'd0;
        end else begin
            case (single_state)
                SINGLE_IDLE: begin
                    if (single_disp_start) begin
                        single_row   <= 3'd0;
                        single_col   <= 3'd0;
                        single_state <= SINGLE_ELEMENT;
                    end
                end
                
                SINGLE_ELEMENT: begin
                    if (!tx_busy && state == ST_SHOW_SELECTED) begin
                        single_state <= (single_col < mat_cols[single_disp_idx] - 1) ? 
                                        SINGLE_SPACE : SINGLE_NEWLINE;
                    end
                end
                
                SINGLE_SPACE: begin
                    if (!tx_busy) begin
                        single_col   <= single_col + 1;
                        single_state <= SINGLE_ELEMENT;
                    end
                end
                
                SINGLE_NEWLINE: begin
                    if (!tx_busy) begin
                        single_col <= 3'd0;
                        if (single_row < mat_rows[single_disp_idx] - 1) begin
                            single_row   <= single_row + 1;
                            single_state <= SINGLE_ELEMENT;
                        end else begin
                            single_state <= SINGLE_DONE;
                        end
                    end
                end
                
                SINGLE_DONE: begin
                    single_state <= SINGLE_IDLE;
                end
            endcase
        end
    end
    
    assign single_disp_done = (single_state == SINGLE_DONE);
    
    //--------------------------------------------------------------------------
    // 主状态机
    //--------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state                <= ST_IDLE;
            query_row            <= 3'd0;
            query_col            <= 3'd0;
            operand_num          <= 2'd0;
            needs_second_operand <= 1'b0;
            needs_scalar         <= 1'b0;
            done                 <= 1'b0;
            busy                 <= 1'b0;
            error                <= 1'b0;
            selected_op1         <= 2'd0;
            selected_op2         <= 2'd0;
            selected_scalar      <= 4'd0;
            op1_valid            <= 1'b0;
            op2_valid            <= 1'b0;
            tx_data              <= 8'd0;
            tx_start             <= 1'b0;
            seg_display_val      <= 4'd0;
            dim_disp_start       <= 1'b0;
            single_disp_start    <= 1'b0;
        end else begin
            tx_start       <= 1'b0;
            dim_disp_start <= 1'b0;
            single_disp_start <= 1'b0;
            
            case (state)
                //--------------------------------------------------------------
                // 空闲状态
                //--------------------------------------------------------------
                ST_IDLE: begin
                    done  <= 1'b0;
                    error <= 1'b0;
                    if (start) begin
                        busy        <= 1'b1;
                        operand_num <= 2'd0;
                        op1_valid   <= 1'b0;
                        op2_valid   <= 1'b0;
                        
                        // 根据运算类型确定选择模式
                        case (op_type)
                            OP_TRANSPOSE, OP_CONVOLVE: begin
                                needs_second_operand <= 1'b0;
                                needs_scalar         <= 1'b0;
                            end
                            OP_ADD, OP_MULTIPLY: begin
                                needs_second_operand <= 1'b1;
                                needs_scalar         <= 1'b0;
                            end
                            OP_SCALAR: begin
                                needs_second_operand <= 1'b0;
                                needs_scalar         <= 1'b1;
                            end
                            default: begin
                                needs_second_operand <= 1'b0;
                                needs_scalar         <= 1'b0;
                            end
                        endcase
                        
                        state <= ST_INPUT_ROW;
                    end
                end
                
                //--------------------------------------------------------------
                // 等待用户输入行数
                //--------------------------------------------------------------
                ST_INPUT_ROW: begin
                    seg_display_val <= {1'b0, sw_dim_input}; // 显示当前输入值
                    if (btn_confirm_posedge) begin
                        if (sw_dim_input >= 3'd1 && sw_dim_input <= 3'd5) begin
                            query_row <= sw_dim_input;
                            state     <= ST_INPUT_COL;
                        end
                        // 如果输入无效，保持当前状态
                    end
                end
                
                //--------------------------------------------------------------
                // 等待用户输入列数
                //--------------------------------------------------------------
                ST_INPUT_COL: begin
                    seg_display_val <= {1'b0, sw_dim_input};
                    if (btn_confirm_posedge) begin
                        if (sw_dim_input >= 3'd1 && sw_dim_input <= 3'd5) begin
                            query_col      <= sw_dim_input;
                            dim_disp_start <= 1'b1; // 启动维度显示器
                            state          <= ST_SHOW_MATRICES;
                        end
                    end
                end
                
                //--------------------------------------------------------------
                // 显示匹配的矩阵
                //--------------------------------------------------------------
                ST_SHOW_MATRICES: begin
                    // 转发维度显示器的UART输出
                    if (dim_tx_start) begin
                        tx_data  <= dim_tx_data;
                        tx_start <= 1'b1;
                    end
                    
                    if (dim_disp_done) begin
                        if (dim_match_count == 0) begin
                            // 没有匹配的矩阵，报错
                            state <= ST_ERROR;
                        end else begin
                            state <= ST_INPUT_SELECT;
                        end
                    end
                end
                
                //--------------------------------------------------------------
                // 等待用户选择矩阵编号
                //--------------------------------------------------------------
                ST_INPUT_SELECT: begin
                    seg_display_val <= {1'b0, sw_dim_input};
                    if (btn_confirm_posedge) begin
                        // 验证选择是否有效 (编号在1-4范围内且该矩阵匹配维度)
                        if (sw_dim_input >= 3'd1 && sw_dim_input <= 3'd4) begin
                            if (dim_match_mask[sw_dim_input - 1]) begin
                                // 有效选择
                                if (operand_num == 0) begin
                                    selected_op1 <= sw_dim_input[1:0] - 1;
                                    op1_valid    <= 1'b1;
                                    single_disp_idx <= sw_dim_input[1:0] - 1;
                                end else begin
                                    selected_op2 <= sw_dim_input[1:0] - 1;
                                    op2_valid    <= 1'b1;
                                    single_disp_idx <= sw_dim_input[1:0] - 1;
                                end
                                single_disp_start <= 1'b1;
                                state <= ST_SHOW_SELECTED;
                            end
                            // 如果选择的矩阵不匹配维度，保持当前状态
                        end
                    end
                end
                
                //--------------------------------------------------------------
                // 显示选定的矩阵
                //--------------------------------------------------------------
                ST_SHOW_SELECTED: begin
                    // 发送矩阵元素
                    if (!tx_busy) begin
                        case (single_state)
                            SINGLE_ELEMENT: begin
                                tx_data  <= 8'h30 + mat_data[single_disp_idx][single_row * 5 + single_col];
                                tx_start <= 1'b1;
                            end
                            SINGLE_SPACE: begin
                                tx_data  <= 8'h20; // 空格
                                tx_start <= 1'b1;
                            end
                            SINGLE_NEWLINE: begin
                                tx_data  <= 8'h0A; // 换行
                                tx_start <= 1'b1;
                            end
                        endcase
                    end
                    
                    if (single_disp_done) begin
                        state <= ST_NEXT_OPERAND;
                    end
                end
                
                //--------------------------------------------------------------
                // 决定下一步
                //--------------------------------------------------------------
                ST_NEXT_OPERAND: begin
                    if (operand_num == 0 && needs_second_operand) begin
                        // 需要选择第二个操作数
                        operand_num <= 2'd1;
                        state       <= ST_INPUT_ROW;
                    end else if (needs_scalar) begin
                        // 需要输入标量
                        state <= ST_INPUT_SCALAR;
                    end else begin
                        // 选择完成
                        state <= ST_FINISH;
                    end
                end
                
                //--------------------------------------------------------------
                // 等待标量输入
                //--------------------------------------------------------------
                ST_INPUT_SCALAR: begin
                    seg_display_val <= sw_scalar;
                    if (btn_confirm_posedge) begin
                        selected_scalar <= sw_scalar;
                        state           <= ST_FINISH;
                    end
                end
                
                //--------------------------------------------------------------
                // 完成
                //--------------------------------------------------------------
                ST_FINISH: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    state <= ST_IDLE;
                end
                
                //--------------------------------------------------------------
                // 错误状态
                //--------------------------------------------------------------
                ST_ERROR: begin
                    error <= 1'b1;
                    busy  <= 1'b0;
                    // 等待确认后返回空闲
                    if (btn_confirm_posedge) begin
                        state <= ST_IDLE;
                    end
                end
                
                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
