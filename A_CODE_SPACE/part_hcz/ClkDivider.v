// 时钟分频模块 - 100MHz转1Hz和1kHz
module ClkDivider(
    input wire clk_100m,      // 100MHz输入时钟
    input wire rst_n,         // 复位
    output reg clk_1hz,       // 1Hz输出时钟
    output reg clk_1khz       // 1kHz输出时钟
);

// =========================== 参数定义 ===========================
localparam CNT_1HZ_MAX = 50_000_000 - 1;   // 1Hz分频计数
localparam CNT_1KHZ_MAX = 50_000 - 1;      // 1kHz分频计数

// =========================== 内部寄存器 ===========================
reg [25:0] cnt_1hz;   // 1Hz分频计数器（27位）
reg [15:0] cnt_1khz;  // 1kHz分频计数器（17位）

// =========================== 1Hz分频逻辑 ===========================
always @(posedge clk_100m or negedge rst_n) begin
    if (!rst_n) begin
        cnt_1hz <= 0;
        clk_1hz <= 0;
    end else begin
        if (cnt_1hz == CNT_1HZ_MAX) begin
            cnt_1hz <= 0;
            clk_1hz <= ~clk_1hz;  // 翻转产生1Hz时钟
        end else begin
            cnt_1hz <= cnt_1hz + 1;
        end
    end
end

// =========================== 1kHz分频逻辑 ===========================
always @(posedge clk_100m or negedge rst_n) begin
    if (!rst_n) begin
        cnt_1khz <= 0;
        clk_1khz <= 0;
    end else begin
        if (cnt_1khz == CNT_1KHZ_MAX) begin
            cnt_1khz <= 0;
            clk_1khz <= ~clk_1khz;  // 翻转产生1kHz时钟
        end else begin
            cnt_1khz <= cnt_1khz + 1;
        end
    end
end

endmodule