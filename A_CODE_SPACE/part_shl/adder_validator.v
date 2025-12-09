// ============================================================
// adder_validator.v
// 功能：判断加法运算的两个矩阵维度是否一致
// 规则：A(m×n) + B(m×n) 要求两个矩阵维度完全相同
// ============================================================
module adder_validator(
    input wire [2:0] dim_A_row,    // 矩阵A的行数
    input wire [2:0] dim_A_col,    // 矩阵A的列数
    input wire [2:0] dim_B_row,    // 矩阵B的行数
    input wire [2:0] dim_B_col,    // 矩阵B的列数
    
    output wire valid_add          // 加法合法标志
);

    // 加法要求：行数相等 且 列数相等
    assign valid_add = (dim_A_row == dim_B_row) && (dim_A_col == dim_B_col) &&
                       (dim_A_row >= 1) && (dim_A_col >= 1);

endmodule
