`timescale 1ns / 1ps
//==============================================================================
// matrix_calculator.v
// 矩阵计算器模块
// 功能：实现转置、加法、标量乘、矩阵乘运算
// 采用逐元素计算方式，每周期完成一个元素的计算
//==============================================================================

module matrix_calculator #(
    parameter MAX_DIM = 5,        // 最大维度
    parameter DATA_WIDTH = 4,     // 输入数据位宽
    parameter RESULT_WIDTH = 16   // 结果数据位宽 (支持乘法累加)
)(
    input wire clk,
    input wire rst_n,
    
    //--------------------------------------------------------------------------
    // 控制接口
    //--------------------------------------------------------------------------
    input wire        start,           // 开始计算 (单周期脉冲)
    input wire [2:0]  opcode,          // 运算类型: 000=转置, 001=加法, 010=标量乘, 011=矩阵乘
    input wire [3:0]  scalar,          // 标量乘法的标量值
    
    //--------------------------------------------------------------------------
    // 矩阵 A 接口 (从 storage 读取)
    //--------------------------------------------------------------------------
    input wire [2:0]  dim_row_A,       // A 的行数
    input wire [2:0]  dim_col_A,       // A 的列数
    output reg [4:0]  read_addr_A,     // 读取地址
    input wire [3:0]  read_data_A,     // 读取数据
    
    //--------------------------------------------------------------------------
    // 矩阵 B 接口 (从 storage 读取, 加法/乘法时使用)
    //--------------------------------------------------------------------------
    input wire [2:0]  dim_row_B,       // B 的行数
    input wire [2:0]  dim_col_B,       // B 的列数
    output reg [4:0]  read_addr_B,     // 读取地址
    input wire [3:0]  read_data_B,     // 读取数据
    
    //--------------------------------------------------------------------------
    // 结果输出接口
    //--------------------------------------------------------------------------
    output reg        busy,            // 计算中
    output reg        done,            // 计算完成 (单周期脉冲)
    output reg [2:0]  result_rows,     // 结果矩阵行数
    output reg [2:0]  result_cols,     // 结果矩阵列数
    
    // 结果读取接口
    input wire [4:0]  result_read_addr,
    output reg [RESULT_WIDTH-1:0] result_read_data
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
    localparam S_IDLE       = 4'd0;
    localparam S_INIT       = 4'd1;    // 初始化
    localparam S_READ_WAIT  = 4'd2;    // 等待读取数据稳定
    localparam S_CALC       = 4'd3;    // 计算
    localparam S_MUL_ACC    = 4'd4;    // 矩阵乘累加
    localparam S_MUL_WRITE  = 4'd5;    // 矩阵乘写结果
    localparam S_WRITE      = 4'd6;    // 写结果
    localparam S_NEXT       = 4'd7;    // 下一个元素
    localparam S_DONE       = 4'd8;    // 完成

    reg [3:0] state;
    
    //==========================================================================
    // 内部变量
    //==========================================================================
    reg [2:0] saved_opcode;
    reg [3:0] saved_scalar;
    
    // 循环计数器
    reg [2:0] i, j, k;          // i=行, j=列, k=乘法中间维度
    
    // 目标维度
    reg [2:0] target_rows, target_cols;
    reg [2:0] common_dim;       // 矩阵乘的公共维度 (A的列数=B的行数)
    
    // 中间计算结果
    reg [RESULT_WIDTH-1:0] accumulator;
    reg [3:0] data_A_reg, data_B_reg;
    
    // 结果存储 (5x5 = 25 个元素)
    reg [RESULT_WIDTH-1:0] result_mem [0:24];
    
    // 写入地址
    reg [4:0] write_addr;

    //==========================================================================
    // 结果读取
    //==========================================================================
    always @(posedge clk) begin
        result_read_data <= result_mem[result_read_addr];
    end

    //==========================================================================
    // 主状态机
    //==========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            busy <= 1'b0;
            done <= 1'b0;
            result_rows <= 3'd0;
            result_cols <= 3'd0;
            read_addr_A <= 5'd0;
            read_addr_B <= 5'd0;
            i <= 3'd0;
            j <= 3'd0;
            k <= 3'd0;
            accumulator <= 0;
            saved_opcode <= 3'd0;
            saved_scalar <= 4'd0;
            target_rows <= 3'd0;
            target_cols <= 3'd0;
            common_dim <= 3'd0;
            write_addr <= 5'd0;
            data_A_reg <= 4'd0;
            data_B_reg <= 4'd0;
        end else begin
            // 默认值
            done <= 1'b0;
            
            case (state)
                //--------------------------------------------------------------
                // 空闲状态
                //--------------------------------------------------------------
                S_IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        busy <= 1'b1;
                        saved_opcode <= opcode;
                        saved_scalar <= scalar;
                        i <= 3'd0;
                        j <= 3'd0;
                        k <= 3'd0;
                        accumulator <= 0;
                        state <= S_INIT;
                    end
                end
                
                //--------------------------------------------------------------
                // 初始化：设置结果维度
                //--------------------------------------------------------------
                S_INIT: begin
                    case (saved_opcode)
                        OP_TRANSPOSE: begin
                            // 转置：结果维度交换
                            target_rows <= dim_col_A;
                            target_cols <= dim_row_A;
                            result_rows <= dim_col_A;
                            result_cols <= dim_row_A;
                        end
                        OP_ADD, OP_SCALAR: begin
                            // 加法/标量乘：维度不变
                            target_rows <= dim_row_A;
                            target_cols <= dim_col_A;
                            result_rows <= dim_row_A;
                            result_cols <= dim_col_A;
                        end
                        OP_MULTIPLY: begin
                            // 矩阵乘：(M x K) * (K x N) = (M x N)
                            target_rows <= dim_row_A;
                            target_cols <= dim_col_B;
                            result_rows <= dim_row_A;
                            result_cols <= dim_col_B;
                            common_dim <= dim_col_A;  // A的列数 = B的行数
                        end
                        default: begin
                            target_rows <= dim_row_A;
                            target_cols <= dim_col_A;
                            result_rows <= dim_row_A;
                            result_cols <= dim_col_A;
                        end
                    endcase
                    
                    // 设置初始读取地址
                    if (saved_opcode == OP_TRANSPOSE) begin
                        // 转置：读 A[i][j], 写 C[j][i]
                        read_addr_A <= 5'd0;  // A[0][0]
                    end else if (saved_opcode == OP_MULTIPLY) begin
                        // 矩阵乘：先读 A[0][0] 和 B[0][0]
                        read_addr_A <= 5'd0;  // A[i][k] = A[0][0]
                        read_addr_B <= 5'd0;  // B[k][j] = B[0][0]
                    end else begin
                        read_addr_A <= 5'd0;
                        read_addr_B <= 5'd0;
                    end
                    
                    state <= S_READ_WAIT;
                end
                
                //--------------------------------------------------------------
                // 等待读取数据稳定 (1个周期延迟)
                //--------------------------------------------------------------
                S_READ_WAIT: begin
                    state <= S_CALC;
                end
                
                //--------------------------------------------------------------
                // 计算
                //--------------------------------------------------------------
                S_CALC: begin
                    case (saved_opcode)
                        //--------------------------------------------------
                        // 转置: C[j][i] = A[i][j]
                        //--------------------------------------------------
                        OP_TRANSPOSE: begin
                            // 计算写入地址：C[j][i] = result[j*5 + i]
                            write_addr <= j * 5 + i;
                            accumulator <= {12'd0, read_data_A};
                            state <= S_WRITE;
                        end
                        
                        //--------------------------------------------------
                        // 加法: C[i][j] = A[i][j] + B[i][j]
                        //--------------------------------------------------
                        OP_ADD: begin
                            write_addr <= i * 5 + j;
                            accumulator <= {12'd0, read_data_A} + {12'd0, read_data_B};
                            state <= S_WRITE;
                        end
                        
                        //--------------------------------------------------
                        // 标量乘: C[i][j] = A[i][j] * scalar
                        //--------------------------------------------------
                        OP_SCALAR: begin
                            write_addr <= i * 5 + j;
                            accumulator <= read_data_A * saved_scalar;
                            state <= S_WRITE;
                        end
                        
                        //--------------------------------------------------
                        // 矩阵乘: C[i][j] = sum(A[i][k] * B[k][j])
                        //--------------------------------------------------
                        OP_MULTIPLY: begin
                            // 累加 A[i][k] * B[k][j]
                            if (k == 0) begin
                                accumulator <= read_data_A * read_data_B;
                            end else begin
                                accumulator <= accumulator + read_data_A * read_data_B;
                            end
                            state <= S_MUL_ACC;
                        end
                    endcase
                end
                
                //--------------------------------------------------------------
                // 矩阵乘累加：检查是否还需要继续累加
                //--------------------------------------------------------------
                S_MUL_ACC: begin
                    if (k + 1 < common_dim) begin
                        // 还需要继续累加
                        k <= k + 1;
                        // 更新读取地址：A[i][k+1], B[k+1][j]
                        read_addr_A <= i * 5 + (k + 1);
                        read_addr_B <= (k + 1) * 5 + j;
                        state <= S_READ_WAIT;
                    end else begin
                        // 累加完成，写入结果
                        write_addr <= i * 5 + j;
                        state <= S_MUL_WRITE;
                    end
                end
                
                //--------------------------------------------------------------
                // 矩阵乘写结果
                //--------------------------------------------------------------
                S_MUL_WRITE: begin
                    result_mem[write_addr] <= accumulator;
                    k <= 3'd0;
                    accumulator <= 0;
                    state <= S_NEXT;
                end
                
                //--------------------------------------------------------------
                // 写结果 (非矩阵乘)
                //--------------------------------------------------------------
                S_WRITE: begin
                    result_mem[write_addr] <= accumulator;
                    state <= S_NEXT;
                end
                
                //--------------------------------------------------------------
                // 移动到下一个元素
                //--------------------------------------------------------------
                S_NEXT: begin
                    // 检查是否完成所有元素
                    if (j + 1 < target_cols) begin
                        // 同一行的下一列
                        j <= j + 1;
                        
                        // 更新读取地址
                        case (saved_opcode)
                            OP_TRANSPOSE: begin
                                read_addr_A <= i * 5 + (j + 1);
                            end
                            OP_ADD, OP_SCALAR: begin
                                read_addr_A <= i * 5 + (j + 1);
                                read_addr_B <= i * 5 + (j + 1);
                            end
                            OP_MULTIPLY: begin
                                read_addr_A <= i * 5 + 0;           // A[i][0]
                                read_addr_B <= 0 * 5 + (j + 1);     // B[0][j+1]
                            end
                        endcase
                        
                        state <= S_READ_WAIT;
                    end else if (i + 1 < target_rows) begin
                        // 下一行的第一列
                        i <= i + 1;
                        j <= 3'd0;
                        
                        case (saved_opcode)
                            OP_TRANSPOSE: begin
                                read_addr_A <= (i + 1) * 5 + 0;
                            end
                            OP_ADD, OP_SCALAR: begin
                                read_addr_A <= (i + 1) * 5 + 0;
                                read_addr_B <= (i + 1) * 5 + 0;
                            end
                            OP_MULTIPLY: begin
                                read_addr_A <= (i + 1) * 5 + 0;     // A[i+1][0]
                                read_addr_B <= 0 * 5 + 0;           // B[0][0]
                            end
                        endcase
                        
                        state <= S_READ_WAIT;
                    end else begin
                        // 全部完成
                        state <= S_DONE;
                    end
                end
                
                //--------------------------------------------------------------
                // 完成状态
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
