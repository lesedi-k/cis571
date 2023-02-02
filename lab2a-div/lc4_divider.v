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

      /*** YOUR CODE HERE ***/

endmodule // lc4_divider

module lc4_divider_one_iter(input  wire [15:0] i_dividend,
                            input  wire [15:0] i_divisor,
                            input  wire [15:0] i_remainder,
                            input  wire [15:0] i_quotient,
                            output wire [15:0] o_dividend,
                            output wire [15:0] o_remainder,
                            output wire [15:0] o_quotient);

      /*** YOUR CODE HERE ***/
      
      // remainder = (remainder << 1) | ((dividend >> 15) & 0x1);
      //   if (remainder < divisor) {
      //       quotient = (quotient << 1);
      //   } else {
      //       quotient = (quotient << 1) | 0x1;
      //       remainder = remainder - divisor;
      //   }

      //   dividend = dividend << 1;

      wire [15:0] remainder = (i_remainder << 1) | ((i_dividend >> 15) & 16'd1);

      begin
            if (remainder < i_divisor)
                  assign o_quotient = i_quotient << 1;
            else 
                  assign o_quotient = (i_quotient << 1) | 16'd1;
                  assign o_remainder = remainder - i_divisor; 
      end 
      assign o_dividend = i_dividend << 1;

      //Questions: should we use  subtractor module?
endmodule

