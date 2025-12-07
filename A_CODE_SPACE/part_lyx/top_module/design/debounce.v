module debounce #(
    parameter CNT_MAX = 21'd1_999_999,  // 20ms for 100MHz clock
    parameter CNT_WIDTH = 21
)(
    input  wire clk,        // 100MHz
    input  wire rst_n,      // active low
    input  wire key_in,     // active low button input
    output reg  key_flag    // single clock pulse when key pressed
);

    reg [CNT_WIDTH-1:0] cnt_20ms;

    // Part 1: 20ms stability counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cnt_20ms <= 0;
        else if (key_in == 1'b1)     // not pressed (active-high noise)
            cnt_20ms <= 0;
        else if (cnt_20ms == CNT_MAX && key_in == 1'b0)
            cnt_20ms <= cnt_20ms;
        else
            cnt_20ms <= cnt_20ms + 1'b1;
    end

    // Part 2: generate a single-cycle key_flag pulse
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            key_flag <= 1'b0;
        else if (cnt_20ms == CNT_MAX - 1)
            key_flag <= 1'b1;  // 1-cycle pulse
        else
            key_flag <= 1'b0;
    end

endmodule
