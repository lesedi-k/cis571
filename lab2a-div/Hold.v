//Hold

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
      wire [15:0] test = i_divisor;

      if (test == 16'b0) begin
            assign o_remainder = 16'b0;
            assign o_quotient = 16'b0;
      end 
      else begin

            wire [16:0][15:0] remainder;
            wire [16:0][15:0] quotient;
            wire [16:0][15:0] dividend;

            assign remainder[0] = 16'b0;
            assign quotient[0] = 16'b0;
            assign dividend[0] = i_dividend;


            genvar i;
            for (i = 0; i < 16; i = i+1) begin
                  if (i != 15) 
                        lc4_divider_one_iter m(.i_dividend(dividend[i]),
                              .i_divisor(i_divisor),
                              .i_remainder(remainder[i]),
                              .i_quotient(quotient[i]),
                              .o_dividend(dividend[i+1]),
                              .o_remainder(remainder[i+1]),
                              .o_quotient(quotient[i+1]));
                  else 
                        lc4_divider_one_iter m(.i_dividend(dividend[i]),
                        .i_divisor(i_divisor),
                        .i_remainder(remainder[i]),
                        .i_quotient(quotient[i]),
                        .o_dividend(dividend[i+1]),
                        .o_remainder(o_remainder),
                        .o_quotient(o_quotient));
            end
      end

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

