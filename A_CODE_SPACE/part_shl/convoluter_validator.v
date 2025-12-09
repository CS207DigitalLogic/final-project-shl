// ============================================================
// convoluter_validator.v
// 功能：判断卷积核与图像尺寸是否满足条件
// 卷积规则：输出尺寸 = 输入尺寸 - 卷积核尺寸 + 1
// 要求：卷积核尺寸 <= 图像尺寸 (两个维度都需满足)
// ============================================================
module convoluter_validator(
    input wire [2:0] kernel_row,    // 卷积核行数 (通常为3)
    input wire [2:0] kernel_col,    // 卷积核列数 (通常为3)
    input wire [3:0] image_row,     // 输入图像行数
    input wire [3:0] image_col,     // 输入图像列数
    
    output wire valid_conv,         // 卷积合法标志
    output wire [3:0] output_row,   // 输出图像行数
    output wire [3:0] output_col    // 输出图像列数
);

    // ============================================================
    // 卷积合法性检查
    // ============================================================
    // 条件1: 卷积核行数 <= 图像行数
    wire row_valid = (kernel_row <= image_row);
    
    // 条件2: 卷积核列数 <= 图像列数
    wire col_valid = (kernel_col <= image_col);
    
    // 条件3: 卷积核尺寸至少为 1x1
    wire kernel_valid = (kernel_row >= 1) && (kernel_col >= 1);
    
    // 条件4: 图像尺寸至少为 1x1
    wire image_valid = (image_row >= 1) && (image_col >= 1);
    
    // 综合判断
    assign valid_conv = row_valid && col_valid && kernel_valid && image_valid;

    // ============================================================
    // 计算输出尺寸 (仅在合法时有意义)
    // 输出尺寸 = 输入尺寸 - 卷积核尺寸 + 1 (无 padding, stride=1)
    // ============================================================
    assign output_row = valid_conv ? (image_row - kernel_row + 1) : 4'd0;
    assign output_col = valid_conv ? (image_col - kernel_col + 1) : 4'd0;

endmodule
