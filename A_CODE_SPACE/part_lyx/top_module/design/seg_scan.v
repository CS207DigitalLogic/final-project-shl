module seg_scan(
    input  wire       clk,
    input  wire       rst_n,

    // two 7-seg values to display
    input  wire [7:0] val_a,   // DK1
    input  wire [7:0] val_b,   // DK4

    // output: shared segment bus + enables
    output reg  [7:0] seg,     // seg0 → DK1-DK4
    output reg        en_a,    // DK1 enable
    output reg        en_b     // DK4 enable
);

    // --------------------------------------------------------------
    // scan counter (controls alternating display)
    // --------------------------------------------------------------
    reg scan_bit;
    reg [15:0] scan_cnt;

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            scan_cnt <= 0;
            scan_bit <= 0;
        end else begin
            scan_cnt <= scan_cnt + 1;
            if (scan_cnt == 16'd20000) begin
                scan_cnt <= 0;
                scan_bit <= ~scan_bit;
            end
        end
    end

    // --------------------------------------------------------------
    // segment output multiplexer (visual persistence)
    // --------------------------------------------------------------
    always @(*) begin
        // default all off
        seg  = 8'b0000_0000;
        en_a = 0;
        en_b = 0;

        if (scan_bit == 1'b0) begin
            // show A
            seg  = val_a;
            en_a = 1;
        end else begin
            // show B
            seg  = val_b;
            en_b = 1;
        end
    end

endmodule
