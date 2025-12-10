module debounce #(
    parameter CNT_MAX = 21'd1_999_999,  // 20ms for 100MHz clock
    parameter CNT_WIDTH = 21
)(
    input  wire clk,        // 100MHz system clock
    input  wire rst_n,      // Active low reset
    input  wire key_in,     // Active HIGH button input (Pressed = 1, Released = 0)
    output reg  key_flag    // Single clock pulse when key is pressed
);

    reg [CNT_WIDTH-1:0] cnt_20ms;

    // Part 1: 20ms stability counter
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            cnt_20ms <= 0;
            
        // [Key Correction]: 
        // Logic inverted to match Active High buttons.
        // If key_in is 0 (released), clear the counter.
        else if (key_in == 1'b0)     
            cnt_20ms <= 0;
            
        // If key_in is 1 (pressed) and counter reached max, hold the value.
        else if (cnt_20ms == CNT_MAX && key_in == 1'b1) 
            cnt_20ms <= cnt_20ms;
            
        // Otherwise (key_in is 1 and counter not full), increment counter.
        else
            cnt_20ms <= cnt_20ms + 1'b1;
    end

    // Part 2: Generate a single-cycle key_flag pulse
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            key_flag <= 1'b0;
        // Pulse generated one cycle before max count
        else if (cnt_20ms == CNT_MAX - 1)
            key_flag <= 1'b1; 
        else
            key_flag <= 1'b0;
    end

endmodule