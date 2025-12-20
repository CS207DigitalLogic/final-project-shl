`timescale 1ns / 1ps
//==============================================================================
// auto_operand_selector.v
// 自动运算数选择器模块
// 功能：根据运算类型自动从存储的矩阵中选择合法的运算数
// 支持的运算：
//   - 转置 (OP_T): 任意一个非空矩阵
//   - 加法 (OP_A): 两个维度相同的矩阵
//   - 标量乘 (OP_B): 任意一个非空矩阵 + 随机标量(0~9)
//   - 矩阵乘 (OP_C): A(m×n) × B(n×p)，A的列数 = B的行数
//==============================================================================

module auto_operand_selector #(
    parameter MAX_MATRICES = 15,
    parameter PTR_WIDTH    = 4
)(
    input wire clk,
    input wire rst_n,
    
    //--------------------------------------------------------------------------
    // 控制接口
    //--------------------------------------------------------------------------
    input wire        start,           // 开始自动选择 (单周期脉冲)
    input wire [2:0]  op_type,         // 运算类型: 000=转置, 001=加法, 010=标量乘, 011=矩阵乘
    input wire [PTR_WIDTH:0] mat_count, // 当前存储的矩阵数量
    
    //--------------------------------------------------------------------------
    // 矩阵读取接口 (连接到 matrix_storage_unit)
    //--------------------------------------------------------------------------
    output reg [PTR_WIDTH-1:0] scan_id_A,    // 扫描读取 ID (端口A)
    input wire [2:0]           dim_row_A,    // 矩阵A行数
    input wire [2:0]           dim_col_A,    // 矩阵A列数
    
    output reg [PTR_WIDTH-1:0] scan_id_B,    // 扫描读取 ID (端口B)
    input wire [2:0]           dim_row_B,    // 矩阵B行数
    input wire [2:0]           dim_col_B,    // 矩阵B列数
    
    //--------------------------------------------------------------------------
    // 随机数种子输入 (可选：由外部LFSR提供)
    //--------------------------------------------------------------------------
    input wire [15:0]          lfsr_seed,    // 外部随机数种子
    
    //--------------------------------------------------------------------------
    // 输出结果
    //--------------------------------------------------------------------------
    output reg        busy,             // 选择中
    output reg        done,             // 选择完成 (单周期脉冲)
    output reg        error,            // 无法找到合法运算数
    
    output reg [PTR_WIDTH-1:0] operand_A_id,  // 选中的运算数 A ID
    output reg [PTR_WIDTH-1:0] operand_B_id,  // 选中的运算数 B ID (仅加法/乘法)
    output reg [3:0]           scalar_value,  // 随机标量值 (仅标量乘)
    
    output reg [2:0]  result_A_row,     // 选中矩阵A的行数
    output reg [2:0]  result_A_col,     // 选中矩阵A的列数
    output reg [2:0]  result_B_row,     // 选中矩阵B的行数
    output reg [2:0]  result_B_col      // 选中矩阵B的列数
);

    //==========================================================================
    // 运算类型定义
    //==========================================================================
    localparam OP_TRANSPOSE = 3'b000;   // 转置
    localparam OP_ADD       = 3'b001;   // 加法
    localparam OP_SCALAR    = 3'b010;   // 标量乘
    localparam OP_MULTIPLY  = 3'b011;   // 矩阵乘

    //==========================================================================
    // 状态机定义
    //==========================================================================
    localparam S_IDLE         = 4'd0;
    localparam S_INIT         = 4'd1;
    localparam S_SCAN_A       = 4'd2;   // 扫描第一个运算数
    localparam S_WAIT_A       = 4'd3;   // 等待A的维度数据稳定
    localparam S_CHECK_A      = 4'd4;   // 检查A是否有效
    localparam S_SCAN_B       = 4'd5;   // 扫描第二个运算数
    localparam S_WAIT_B       = 4'd6;   // 等待B的维度数据稳定
    localparam S_CHECK_B      = 4'd7;   // 检查B是否满足条件
    localparam S_FOUND        = 4'd8;   // 找到合法组合
    localparam S_ERROR        = 4'd9;   // 无法找到合法组合
    localparam S_DONE         = 4'd10;
    
    reg [3:0] state;
    
    //==========================================================================
    // 内部变量
    //==========================================================================
    reg [2:0] saved_op_type;
    reg [PTR_WIDTH-1:0] idx_A, idx_B;  // 扫描索引
    reg [PTR_WIDTH:0] saved_mat_count;
    
    // 暂存第一个找到的有效矩阵信息
    reg [PTR_WIDTH-1:0] first_valid_id;
    reg [2:0] first_valid_row, first_valid_col;
    reg       first_valid_found;
    
    // 内部 LFSR 用于生成随机标量
    reg [15:0] lfsr;
    wire [3:0] random_scalar = lfsr[3:0] % 10;  // 0~9
    
    //==========================================================================
    // LFSR 随机数生成
    //==========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr <= 16'hACE1;
        end else begin
            // 持续运行 LFSR 保持随机性
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
        end
    end
    
    //==========================================================================
    // 主状态机
    //==========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            busy <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            operand_A_id <= 0;
            operand_B_id <= 0;
            scalar_value <= 4'd0;
            result_A_row <= 3'd0;
            result_A_col <= 3'd0;
            result_B_row <= 3'd0;
            result_B_col <= 3'd0;
            scan_id_A <= 0;
            scan_id_B <= 0;
            idx_A <= 0;
            idx_B <= 0;
            saved_op_type <= 3'd0;
            saved_mat_count <= 0;
            first_valid_id <= 0;
            first_valid_row <= 3'd0;
            first_valid_col <= 3'd0;
            first_valid_found <= 1'b0;
        end else begin
            // 默认值
            done <= 1'b0;
            
            case (state)
                //--------------------------------------------------------------
                // 空闲状态
                //--------------------------------------------------------------
                S_IDLE: begin
                    busy <= 1'b0;
                    error <= 1'b0;
                    if (start) begin
                        busy <= 1'b1;
                        saved_op_type <= op_type;
                        saved_mat_count <= mat_count;
                        idx_A <= 0;
                        idx_B <= 0;
                        first_valid_found <= 1'b0;
                        // 修复：清除之前的结果
                        operand_A_id <= 0;
                        operand_B_id <= 0;
                        result_A_row <= 3'd0;
                        result_A_col <= 3'd0;
                        result_B_row <= 3'd0;
                        result_B_col <= 3'd0;
                        state <= S_INIT;
                    end
                end
                
                //--------------------------------------------------------------
                // 初始化
                //--------------------------------------------------------------
                S_INIT: begin
                    // 检查是否有矩阵
                    if (saved_mat_count == 0) begin
                        state <= S_ERROR;
                    end else begin
                        scan_id_A <= 0;
                        idx_A <= 0;
                        state <= S_WAIT_A;
                    end
                end
                
                //--------------------------------------------------------------
                // 等待A的维度数据稳定（需要2个周期）
                //--------------------------------------------------------------
                S_WAIT_A: begin
                    state <= S_SCAN_A;  // 增加一个等待周期
                end
                
                //--------------------------------------------------------------
                // 扫描A（额外的等待周期）
                //--------------------------------------------------------------
                S_SCAN_A: begin
                    state <= S_CHECK_A;
                end
                
                //--------------------------------------------------------------
                // 检查当前矩阵A是否有效
                //--------------------------------------------------------------
                S_CHECK_A: begin
                    // 检查矩阵是否非空
                    if (dim_row_A != 0 && dim_col_A != 0) begin
                        case (saved_op_type)
                            OP_TRANSPOSE, OP_SCALAR: begin
                                // 转置/标量乘：找到第一个非空矩阵即可
                                operand_A_id <= idx_A;
                                result_A_row <= dim_row_A;
                                result_A_col <= dim_col_A;
                                if (saved_op_type == OP_SCALAR) begin
                                    scalar_value <= random_scalar;
                                end
                                state <= S_FOUND;
                            end
                            
                            OP_ADD: begin
                                // 加法：需要找两个维度相同的矩阵
                                if (!first_valid_found) begin
                                    // 记录第一个有效矩阵
                                    first_valid_id <= idx_A;
                                    first_valid_row <= dim_row_A;
                                    first_valid_col <= dim_col_A;
                                    first_valid_found <= 1'b1;
                                    // 从下一个开始找第二个
                                    if (idx_A + 1 < saved_mat_count) begin
                                        idx_B <= idx_A + 1;
                                        scan_id_B <= idx_A + 1;
                                        state <= S_WAIT_B;
                                    end else begin
                                        // 只有一个有效矩阵，无法进行加法
                                        state <= S_ERROR;
                                    end
                                end else begin
                                    // 检查是否与第一个矩阵维度相同
                                    if (dim_row_A == first_valid_row && 
                                        dim_col_A == first_valid_col) begin
                                        operand_A_id <= first_valid_id;
                                        operand_B_id <= idx_A;
                                        result_A_row <= first_valid_row;
                                        result_A_col <= first_valid_col;
                                        result_B_row <= dim_row_A;
                                        result_B_col <= dim_col_A;
                                        state <= S_FOUND;
                                    end else begin
                                        // 不匹配，继续扫描
                                        if (idx_A + 1 < saved_mat_count) begin
                                            idx_A <= idx_A + 1;
                                            scan_id_A <= idx_A + 1;
                                            state <= S_WAIT_A;
                                        end else begin
                                            state <= S_ERROR;
                                        end
                                    end
                                end
                            end
                            
                            OP_MULTIPLY: begin
                                // 矩阵乘：需要找A和B使得A的列数 = B的行数
                                // 记录当前有效矩阵A
                                first_valid_id <= idx_A;
                                first_valid_row <= dim_row_A;
                                first_valid_col <= dim_col_A;
                                first_valid_found <= 1'b1;
                                // 从头开始找B
                                idx_B <= 0;
                                scan_id_B <= 0;
                                state <= S_WAIT_B;
                            end
                            
                            default: state <= S_ERROR;
                        endcase
                    end else begin
                        // 当前矩阵为空，继续扫描
                        if (idx_A + 1 < saved_mat_count) begin
                            idx_A <= idx_A + 1;
                            scan_id_A <= idx_A + 1;
                            state <= S_WAIT_A;
                        end else begin
                            state <= S_ERROR;
                        end
                    end
                end
                
                //--------------------------------------------------------------
                // 等待B的维度数据稳定（需要2个周期）
                //--------------------------------------------------------------
                S_WAIT_B: begin
                    state <= S_SCAN_B;  // 增加一个等待周期
                end
                
                //--------------------------------------------------------------
                // 扫描B（额外的等待周期）
                //--------------------------------------------------------------
                S_SCAN_B: begin
                    state <= S_CHECK_B;
                end
                
                //--------------------------------------------------------------
                // 检查B是否满足条件
                //--------------------------------------------------------------
                S_CHECK_B: begin
                    if (dim_row_B != 0 && dim_col_B != 0) begin
                        case (saved_op_type)
                            OP_ADD: begin
                                // 加法：检查维度是否相同
                                if (dim_row_B == first_valid_row && 
                                    dim_col_B == first_valid_col &&
                                    idx_B != first_valid_id) begin
                                    // 找到匹配的！
                                    operand_A_id <= first_valid_id;
                                    operand_B_id <= idx_B;
                                    result_A_row <= first_valid_row;
                                    result_A_col <= first_valid_col;
                                    result_B_row <= dim_row_B;
                                    result_B_col <= dim_col_B;
                                    state <= S_FOUND;
                                end else begin
                                    // 不匹配，继续扫描B
                                    if (idx_B + 1 < saved_mat_count) begin
                                        idx_B <= idx_B + 1;
                                        scan_id_B <= idx_B + 1;
                                        state <= S_WAIT_B;
                                    end else begin
                                        // B扫描完毕，没找到匹配的
                                        state <= S_ERROR;
                                    end
                                end
                            end
                            
                            OP_MULTIPLY: begin
                                // 矩阵乘：检查A的列数 = B的行数
                                if (first_valid_col == dim_row_B) begin
                                    // 找到匹配的！
                                    operand_A_id <= first_valid_id;
                                    operand_B_id <= idx_B;
                                    result_A_row <= first_valid_row;
                                    result_A_col <= first_valid_col;
                                    result_B_row <= dim_row_B;
                                    result_B_col <= dim_col_B;
                                    state <= S_FOUND;
                                end else begin
                                    // 不匹配，继续扫描B
                                    if (idx_B + 1 < saved_mat_count) begin
                                        idx_B <= idx_B + 1;
                                        scan_id_B <= idx_B + 1;
                                        state <= S_WAIT_B;
                                    end else begin
                                        // B扫描完毕，尝试下一个A
                                        if (idx_A + 1 < saved_mat_count) begin
                                            idx_A <= idx_A + 1;
                                            scan_id_A <= idx_A + 1;
                                            first_valid_found <= 1'b0;
                                            state <= S_WAIT_A;
                                        end else begin
                                            state <= S_ERROR;
                                        end
                                    end
                                end
                            end
                            
                            default: state <= S_ERROR;
                        endcase
                    end else begin
                        // B为空，继续扫描
                        if (idx_B + 1 < saved_mat_count) begin
                            idx_B <= idx_B + 1;
                            scan_id_B <= idx_B + 1;
                            state <= S_WAIT_B;
                        end else begin
                            // B扫描完毕
                            if (saved_op_type == OP_MULTIPLY) begin
                                // 矩阵乘：尝试下一个A
                                if (idx_A + 1 < saved_mat_count) begin
                                    idx_A <= idx_A + 1;
                                    scan_id_A <= idx_A + 1;
                                    first_valid_found <= 1'b0;
                                    state <= S_WAIT_A;
                                end else begin
                                    state <= S_ERROR;
                                end
                            end else begin
                                state <= S_ERROR;
                            end
                        end
                    end
                end
                
                //--------------------------------------------------------------
                // 找到合法组合
                //--------------------------------------------------------------
                S_FOUND: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    error <= 1'b0;
                    state <= S_IDLE;
                end
                
                //--------------------------------------------------------------
                // 无法找到合法组合
                //--------------------------------------------------------------
                S_ERROR: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    error <= 1'b1;
                    state <= S_IDLE;
                end
                
                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
