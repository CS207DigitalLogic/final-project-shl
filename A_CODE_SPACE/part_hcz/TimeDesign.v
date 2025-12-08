// 时间配置模块
module TimeDesign(
    input wire clk,
    input wire rst_n,
    input wire [3:0] dip_sw,      // 拨码开关输入
    input wire config_valid,      // 配置有效信号
    output reg [3:0] time_setting // 配置的时间值(5-15)
);

// =========================== 参数定义 ===========================
localparam MIN_TIME = 5;   // 最小时间
localparam MAX_TIME = 15;  // 最大时间
localparam DEFAULT_TIME = 10;  // 默认时间

// =========================== 配置逻辑 ===========================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        time_setting <= DEFAULT_TIME;
    end else if (config_valid) begin
        // 检查输入范围，限制在5-15秒
        if (dip_sw < MIN_TIME) begin
            time_setting <= MIN_TIME;
        end else if (dip_sw > MAX_TIME) begin
            time_setting <= MAX_TIME;
        end else begin
            time_setting <= dip_sw;
        end
    end
end

endmodule