// 数码管显示模块
module SegDisplay(
    input wire clk_100m,
    input wire clk_1khz,        // 数码管扫描时钟
    input wire rst_n,
    input wire [3:0] value,     // 要显示的值(0-15)
    input wire [1:0] state,     // 状态指示
    output reg [3:0] seg_sel,   // 数码管位选
    output reg [7:0] seg_data   // 数码管段选
);

// =========================== 内部寄存器 ===========================
reg [1:0] scan_cnt;             // 扫描计数器
reg [3:0] display_val;          // 当前显示的值
reg [7:0] seg_data_raw;         // 原始段选数据

// =========================== 数码管扫描 ===========================
always @(posedge clk_1khz or negedge rst_n) begin
    if (!rst_n) begin
        scan_cnt <= 2'b00;
        seg_sel <= 4'b1111;
    end else begin
        scan_cnt <= scan_cnt + 1;
        case (scan_cnt)
            2'b00: begin
                seg_sel <= 4'b1110;  // 第一个数码管（个位）
                display_val <= value % 10;
            end
            2'b01: begin
                seg_sel <= 4'b1101;  // 第二个数码管（十位）
                display_val <= value / 10;
            end
            2'b10: begin
                seg_sel <= 4'b1111;  // 关闭显示
            end
            default: begin
                seg_sel <= 4'b1111;  // 关闭显示
            end
        endcase
    end
end

// =========================== 七段译码器 ===========================
always @(*) begin
    case (display_val)
        4'h0: seg_data_raw = 8'b1100_0000;  // 0
        4'h1: seg_data_raw = 8'b1111_1001;  // 1
        4'h2: seg_data_raw = 8'b1010_0100;  // 2
        4'h3: seg_data_raw = 8'b1011_0000;  // 3
        4'h4: seg_data_raw = 8'b1001_1001;  // 4
        4'h5: seg_data_raw = 8'b1001_0010;  // 5
        4'h6: seg_data_raw = 8'b1000_0010;  // 6
        4'h7: seg_data_raw = 8'b1111_1000;  // 7
        4'h8: seg_data_raw = 8'b1000_0000;  // 8
        4'h9: seg_data_raw = 8'b1001_0000;  // 9
        default: seg_data_raw = 8'b1111_1111; // 全灭
    endcase
end

// =========================== 根据状态调整显示 ===========================可删除
always @(*) begin
    seg_data = seg_data_raw;
    
    // 暂停状态下，点亮个位数码管的小数点
    if (state == 2'b10 && scan_cnt == 2'b00) begin
        seg_data = seg_data_raw & 8'b0111_1111;
    end
    
    // 完成状态下，数码管闪烁
    if (state == 2'b11) begin
        // 使用1Hz时钟控制闪烁
        reg [25:0] flash_cnt;
        reg flash_enable;
        
        // 简单的闪烁计数器
        always @(posedge clk_100m or negedge rst_n) begin
            if (!rst_n) begin
                flash_cnt <= 0;
                flash_enable <= 1;
            end else begin
                if (flash_cnt == 50_000_000) begin  // 0.5秒
                    flash_cnt <= 0;
                    flash_enable <= ~flash_enable;
                end else begin
                    flash_cnt <= flash_cnt + 1;
                end
            end
        end
        
        if (!flash_enable) begin
            seg_data = 8'b1111_1111;  // 关闭显示（闪烁）
        end
    end
end

endmodule