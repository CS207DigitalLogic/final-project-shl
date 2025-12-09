// ============================================================
// multiplexer_validator.v
// 功能：判断矩阵乘法的两个矩阵维度是否满足规则
// 规则：A(m×n) × B(n×p) = C(m×p)，要求 A的列数 = B的行数
// ============================================================
module multiplexer_validator(
    input wire [2:0] dim_A_row,    // 矩阵A的行数 (m)
    input wire [2:0] dim_A_col,    // 矩阵A的列数 (n)
    input wire [2:0] dim_B_row,    // 矩阵B的行数 (n)
    input wire [2:0] dim_B_col,    // 矩阵B的列数 (p)
    
    output wire valid_mul,         // 乘法合法标志
    output wire [2:0] result_row,  // 结果矩阵行数 (m)
    output wire [2:0] result_col   // 结果矩阵列数 (p)
);

    // 乘法要求：A的列数 == B的行数
    wire dim_match = (dim_A_col == dim_B_row);
    
    // 维度有效性检查
    wire dim_valid = (dim_A_row >= 1) && (dim_A_col >= 1) && 
                     (dim_B_row >= 1) && (dim_B_col >= 1);
    
    assign valid_mul = dim_match && dim_valid;
    
    // 结果矩阵尺寸
    assign result_row = valid_mul ? dim_A_row : 3'd0;
    assign result_col = valid_mul ? dim_B_col : 3'd0;

endmodule
