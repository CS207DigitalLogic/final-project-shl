module seg_scan(
    input  wire       clk,
    input  wire       rst_n,

    // two 7-seg values to display
    input  wire [7:0] val_a,   // DK1 value
    input  wire [7:0] val_b,   // DK4 value

    // output: shared segment bus + enables
    output reg  [7:0] seg,     // seg0 -> DK1-DK4
    output reg        en_a,    // DK1 enable
    output reg        en_b     // DK4 enable
);

    // --------------------------------------------------------------
    // Timer Parameters
    // --------------------------------------------------------------
    // Total cycle time for one digit (refresh rate control)
    // 50,000 cycles @ 100MHz = 0.5ms per switch (1kHz flicker)
    localparam SWITCH_TIME = 16'd50000; 
    
    // The "Dead Time" or "Blanking Time"
    // We wait 2000 cycles (20us) after turning off inputs before turning on new ones.
    localparam BLANK_TIME  = 16'd2000;

    reg [15:0] cnt;
    reg        current_digit; // 0 = DK1 (A), 1 = DK4 (B)

    // --------------------------------------------------------------
    // Main Sequential Control Logic
    // --------------------------------------------------------------
    // Using sequential logic (posedge clk) ensures glitch-free outputs.
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            cnt           <= 0;
            current_digit <= 0;
            seg           <= 8'h00; // Assuming active high segments
            en_a          <= 0;
            en_b          <= 0;
        end else begin
            cnt <= cnt + 1'b1;

            // =========================================================
            // PHASE 1: TURN OFF (Start of switch)
            // =========================================================
            if (cnt == SWITCH_TIME) begin
                cnt  <= 0;
                en_a <= 0;   // Force OFF immediately
                en_b <= 0;   // Force OFF immediately
                
                // Toggle state for the NEXT phase
                current_digit <= ~current_digit; 
            end
            
            // =========================================================
            // PHASE 2: UPDATE DATA (Middle of Blanking Interval)
            // =========================================================
            // We update the data segment while enables are still OFF.
            // This prevents the "old" digit from seeing the "new" data.
            else if (cnt == (BLANK_TIME / 2)) begin
                if (current_digit == 0)
                    seg <= val_a; // Pre-load Data A
                else
                    seg <= val_b; // Pre-load Data B
            end

            // =========================================================
            // PHASE 3: TURN ON (End of Blanking Interval)
            // =========================================================
            // Now that data is stable and old transistors are fully off,
            // we turn on the new enable.
            else if (cnt == BLANK_TIME) begin
                if (current_digit == 0)
                    en_a <= 1; // Turn ON A
                else
                    en_b <= 1; // Turn ON B
            end
        end
    end

endmodule