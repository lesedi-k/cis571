/* Yang Du, ydu24 */
/* Lesedi Kereteletswe, lesedik */

`timescale 1ns / 1ps
`default_nettype none

/**
 * @param a first 1-bit input
 * @param b second 1-bit input
 * @param g whether a and b generate a carry
 * @param p whether a and b would propagate an incoming carry
 */
module gp1(input wire a, b,
           output wire g, p);
   assign g = a & b;
   assign p = a | b;
endmodule

/**
 * Computes aggregate generate/propagate signals over a 4-bit window.
 * @param gin incoming generate signals 
 * @param pin incoming propagate signals
 * @param cin the incoming carry
 * @param gout whether these 4 bits collectively generate a carry (ignoring cin)
 * @param pout whether these 4 bits collectively would propagate an incoming carry (ignoring cin)
 * @param cout the carry outs for the low-order 3 bits
 */
module gp4(input wire [3:0] gin, pin,
           input wire cin,
           output wire gout, pout,
           output wire [2:0] cout);
    
    assign cout[0] = (cin & pin[0]) | gin[0];

    assign pout = pin[0] & pin[1] & pin[2] & pin[3];
    
    wire [1:0] c1im;

    assign c1im[0] = cin & pin[0] & pin[1];
    assign c1im[1] = gin[0] & pin[1];

    assign cout[1] = (| c1im) | gin[1];
    
    wire [2:0] c2im;

    assign c2im[0] = cin & pin[0] & pin[1] & pin[2];
    assign c2im[1] = gin[0] & pin[1] & pin[2];
    assign c2im[2] = gin[1] & pin[2];

    assign cout[2] = (| c2im) | gin[2];

    wire [2:0] gim;

    assign gim[0] = gin[0] & pin[1] & pin[2] & pin[3];
    assign gim[1] = gin[1] & pin[2] & pin[3];
    assign gim[2] = gin[2] & pin[3];
    
    assign gout = (| gim) | gin[3];
endmodule

/**
 * 16-bit Carry-Lookahead Adder
 * @param a first input
 * @param b second input
 * @param cin carry in
 * @param sum sum of a + b + carry-in
 */
module cla16
  (input wire [15:0]  a, b,
   input wire         cin,
   output wire [15:0] sum);
  
  wire [3:0] gim;
  wire [3:0] pim;
  wire [15:0] cout;
  wire [15:0] g1out;
  wire [15:0] p1out;
  
  assign cout[0] = cin;

  genvar i;
  genvar j;
  generate
    for (i = 0; i < 4; i = i + 1) begin: inter_gp4

      for (j = 0; j < 4; j = j + 1) begin: inter_gp1
        gp1 gp1l1(  .a(a[i * 4 + j]),
                    .b(b[i * 4 + j]),
                    .g(g1out[i * 4 + j]),
                    .p(p1out[i * 4 + j]));
        
        assign sum[i * 4 + j] = a[i * 4 + j] ^ b[i * 4 + j] ^ cout[i * 4 + j];
      end

      gp4 gp4l1(  .gin(g1out[i * 4 + 3: i * 4]),
                  .pin(p1out[i * 4 + 3: i * 4]),
                  .cin(cout[i * 4]),
                  .gout(gim[i]),
                  .pout(pim[i]),
                  .cout(cout[i * 4 + 3: i * 4 + 1]));
    end
  endgenerate

  gp4 gp4l2(  .gin(gim),
              .pin(pim),
              .cin(cin),
              .cout({cout[12], cout[8], cout[4]}));
  
endmodule


/** Lab 2 Extra Credit, see details at
  https://github.com/upenn-acg/cis501/blob/master/lab2-alu/lab2-cla.md#extra-credit
 If you are not doing the extra credit, you should leave this module empty.
 */
module gpn
  #(parameter N = 4)
  (input wire [N-1:0] gin, pin,
   input wire  cin,
   output wire gout, pout,
   output wire [N-2:0] cout);
 
endmodule
