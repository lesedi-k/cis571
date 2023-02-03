//HOLD

/* 
      TODO: INSERT NAME AND PENNKEY HERE 
      NAMES: Lesedi Kereteletswe, 
      PENNKEYS: lesedik

*/

`timescale 1ns / 1ps
`default_nettype none

module lc4_divider(input  wire [15:0] i_dividend,
                   input  wire [15:0] i_divisor,
                   output wire [15:0] o_remainder,
                   output wire [15:0] o_quotient);

      wire[15:0] q_inter[14:0];
      wire[15:0] r_inter[14:0];
      wire[15:0] d_inter[14:0];

      lc4_divider_one_iter divi_first(    .i_dividend(i_dividend), 
                                    .i_divisor(i_divisor), 
                                    .i_remainder(16'b0), 
                                    .i_quotient(16'b0), 
                                    .o_dividend(d_inter[0]), 
                                    .o_remainder(r_inter[0]), 
                                    .o_quotient(q_inter[0]));


      genvar i;
      generate
      for (i = 1; i < 15; i = i + 1) begin: middle_divider
            lc4_divider_one_iter divi(    .i_dividend(d_inter[i-1]), 
                                          .i_divisor(i_divisor), 
                                          .i_remainder(r_inter[i-1]), 
                                          .i_quotient(q_inter[i-1]), 
                                          .o_dividend(d_inter[i]), 
                                          .o_remainder(r_inter[i]), 
                                          .o_quotient(q_inter[i]));
      end
      endgenerate

      wire[15:0] final_r;
      wire[15:0] final_q;

      lc4_divider_one_iter divi_last(    .i_dividend(d_inter[14]), 
                                          .i_divisor(i_divisor), 
                                          .i_remainder(r_inter[14]), 
                                          .i_quotient(q_inter[14]), 
                                          .o_remainder(final_r[15:0]), 
                                          .o_quotient(final_q[15:0]));

      assign o_remainder = (i_divisor == 0) ? (16'd0) : (final_r);
      assign o_quotient = (i_divisor == 0) ? (16'd0) : (final_q);

endmodule 

module lc4_divider_one_iter(input  wire [15:0] i_dividend,
                            input  wire [15:0] i_divisor,
                            input  wire [15:0] i_remainder,
                            input  wire [15:0] i_quotient,
                            output wire [15:0] o_dividend,
                            output wire [15:0] o_remainder,
                            output wire [15:0] o_quotient);

      wire [15:0] remainder = (i_remainder <<< 1) | ((i_dividend >>> 15) & 16'd1);
      assign o_quotient = (remainder < i_divisor) ? (i_quotient <<< 1) : ((i_quotient <<< 1) | 16'd1 ) ;
      assign o_remainder = (remainder >= i_divisor) ? (remainder - i_divisor) : remainder; 
      assign o_dividend = i_dividend << 1; 
   
endmodule

