module KeyDebounce #(
                              // clock frequency(Mhz), 50 MHz
   parameter CLK_FREQ = 50_000_000,
   parameter KEY_CNT = 8
)
(
   input                clk,               // clock input
   input  [KEY_CNT-1:0] keys,              // input key pins, raw input
   output [KEY_CNT-1:0] keys_stable        // output stable key status, 0 - press down
);


// generte key debounce module
   generate
      genvar i;
      for(i=0;i<KEY_CNT;i=i+1) begin : key_debounce

         bit_keydebounce #(
            .CLK_FREQ(CLK_FREQ)
         ) u_keydeb (
            .clk     (clk           ), 
            .key     (keys[i]       ), 
            .key_done(keys_stable[i]), 
            .rst_n   (1             )
         );

      end
   endgenerate



endmodule
