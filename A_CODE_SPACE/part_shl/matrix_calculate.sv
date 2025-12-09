module matrix_calculate(
    input wire clk,             // 时钟
    input wire rst_n,           // 复位（低电平有效）
    input wire start,           // 开始信号
    input wire [1:0] opcode,    // 00:转置, 01:加法, 10:标量乘, 11:矩阵乘
    
    // 矩阵维度输入 (M x N)
    input wire [2:0] matrix_A_row, // A的行数
    input wire [2:0] matrix_A_col, // A的列数
    input wire [2:0] matrix_B_row, // B的行数
    input wire [2:0] matrix_B_col, // B的列数
    
    // 标量输入
    input wire [3:0] scalar,
    
    // 矩阵数据输入 (扁平化数组，最大25个元素)
    // 注意：如果vivado报错，把 [3:0] matrix_A [0:24] 改为 input [99:0] flat_A 并手动拆分
    input wire [3:0] matrix_A [0:24], 
    input wire [3:0] matrix_B [0:24],
    
    // 输出
    output reg done,                        // 完成信号
    output reg [15:0] matrix_C [0:24],      // 结果矩阵 (位宽设为16防止溢出)
    output reg [2:0] matrix_C_row,          // 结果的行数
    output reg [2:0] matrix_C_col           // 结果的列数
);

    // ============================================================
    // 1. 内部变量定义
    // ============================================================
    // 状态定义
    localparam S_IDLE = 2'd0;
    localparam S_CALC = 2'd1;
    localparam S_DONE = 2'd2;
    
    reg [1:0] state;
    
    // 循环计数器 (i:行, j:列, k:矩阵乘法中间维)
    reg [2:0] i, j, k; 
    
    // 矩阵乘法专用的累加器
    reg [15:0] sum_acc;

    // ============================================================
    // 2. 状态机逻辑
    // ============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 复位：清零所有东西
            state <= S_IDLE;
            done <= 0;
            i <= 0; j <= 0; k <= 0;
            sum_acc <= 0;
            // 注意：matrix_C 是 output reg，复位时通常不需要清空整个数组，
            // 但为了严谨可以加循环清空，这里省略以节省资源
        end 
        else begin
            case (state)
                // --- 闲置状态 ---
                S_IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= S_CALC;
                        i <= 0; j <= 0; k <= 0;
                        sum_acc <= 0;
                        
                        // 预先设置好结果矩阵的维度
                        case (opcode)
                            2'b00: begin matrix_C_row <= matrix_A_col; matrix_C_col <= matrix_A_row; end // 转置：维度交换
                            2'b01: begin matrix_C_row <= matrix_A_row; matrix_C_col <= matrix_A_col; end // 加法：维度不变
                            2'b10: begin matrix_C_row <= matrix_A_row; matrix_C_col <= matrix_A_col; end // 标量乘：维度不变
                            2'b11: begin matrix_C_row <= matrix_A_row; matrix_C_col <= matrix_B_col; end // 矩阵乘：(MxK) * (KxN) = (MxN)
                        endcase
                    end
                end

                // --- 计算状态 ---
                S_CALC: begin
                    case (opcode)
                        // ----------------------------------------------------
                        // 模式 0: 矩阵转置 (Transpose)
                        // ----------------------------------------------------
                        2'b00: begin
                            // 逻辑：C[j][i] = A[i][j]
                            // 对应一维地址：C[j*5 + i] = A[i*5 + j]
                            // 注意：虽然矩阵实际大小可能只有2x2，但存储时通常按固定宽度5来存，
                            // 所以换行时要跳过 5 个单位。
                            
                            matrix_C[j*5 + i] <= matrix_A[i*5 + j]; // 核心计算
                            
                            // 更新循环变量 (相当于双层 for 循环)
                            if (j == matrix_A_col - 1) begin
                                j <= 0;
                                if (i == matrix_A_row - 1) state <= S_DONE; // 算完了
                                else i <= i + 1;
                            end else begin
                                j <= j + 1;
                            end
                        end

                        // ----------------------------------------------------
                        // 模式 1: 矩阵加法 (Add)
                        // ----------------------------------------------------
                        2'b01: begin
                            // 逻辑：C[i][j] = A[i][j] + B[i][j]
                            matrix_C[i*5 + j] <= matrix_A[i*5 + j] + matrix_B[i*5 + j];
                            
                            // 更新循环变量
                            if (j == matrix_A_col - 1) begin
                                j <= 0;
                                if (i == matrix_A_row - 1) state <= S_DONE;
                                else i <= i + 1;
                            end else begin
                                j <= j + 1;
                            end
                        end

                        // ----------------------------------------------------
                        // 模式 2: 标量乘法 (Scalar Mul)
                        // ----------------------------------------------------
                        2'b10: begin
                            // 逻辑：C[i][j] = A[i][j] * scalar
                            matrix_C[i*5 + j] <= matrix_A[i*5 + j] * scalar;
                            
                            // 更新循环变量
                            if (j == matrix_A_col - 1) begin
                                j <= 0;
                                if (i == matrix_A_row - 1) state <= S_DONE;
                                else i <= i + 1;
                            end else begin
                                j <= j + 1;
                            end
                        end

                        // ----------------------------------------------------
                        // 模式 3: 矩阵乘法 (Matrix Mul) - 最难的部分
                        // ----------------------------------------------------
                        2'b11: begin
                            // 逻辑：C[i][j] = sum( A[i][k] * B[k][j] )
                            // i: 结果的行 (0 ~ A_row-1)
                            // j: 结果的列 (0 ~ B_col-1)
                            // k: 公共维度 (0 ~ A_col-1)
                            
                            if (k == 0) begin
                                // 刚开始算这个格子，先算第一项
                                sum_acc <= matrix_A[i*5 + k] * matrix_B[k*5 + j];
                                k <= k + 1;
                            end 
                            else if (k < matrix_A_col) begin
                                // 还没加完，继续累加
                                sum_acc <= sum_acc + matrix_A[i*5 + k] * matrix_B[k*5 + j];
                                k <= k + 1;
                            end 
                            
                            // 当 k 走到尽头，说明 C[i][j] 算完了
                            if (k == matrix_A_col) begin
                                matrix_C[i*5 + j] <= sum_acc; // 保存结果
                                k <= 0;                       // 重置 k
                                sum_acc <= 0;                 // 清空累加器
                                
                                // 移动 j (列)
                                if (j == matrix_B_col - 1) begin
                                    j <= 0;
                                    // 移动 i (行)
                                    if (i == matrix_A_row - 1) state <= S_DONE;
                                    else i <= i + 1;
                                end else begin
                                    j <= j + 1;
                                end
                            end
                        end
                    endcase
                end

                // --- 完成状态 ---
                S_DONE: begin
                    done <= 1;
                    // 等待 start 变低后再回到 IDLE，或者直接回，取决于上层模块的设计
                    // 这里假设直接回 IDLE 等待下一次 start
                    state <= S_IDLE; 
                end
            endcase
        end
    end

endmodule