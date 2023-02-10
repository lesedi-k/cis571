
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

          assign cout[0] = gin[0] | (pin[0] & cin);

          wire p10 = pin[0] & pin[1];
          wire g10 = gin[1] | (gin[0] & pin[1]);
          assign cout[1] = (p10 & cin) | g10;

          wire p20 = (&pin[2:0]);
          wire g20 = (g10 & pin[2]);
          assign cout[2] =  (p20 & cin) | g20 | gin[2] ;

          assign pout = (& pin);

      
          wire p31 = (&pin[3:1]);
          wire p32 = (&pin[3:2]);
          wire g32 = (gin[2] & pin[3]) | gin[3];
          assign gout = g32 | (p32 & g10);

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

    wire[15:0] g, p, c; 
    wire g30, g150, g74, g118, g1512; 
    wire p30, p150, p74, p118, p1512;

    generate
      for (genvar i = 0; i < 16; i = i + 1) begin
          gp1 m(.a(a[i]), .b(b[i]), .g(g[i]), .p(p[i]));
      end
    endgenerate

    /*
      get carry values
    */
    assign c[0] = cin;

    gp4 first( .gin(g[3:0]) , .pin(p[3:0]), 
      .cin(c[0]), 
      .gout(g30), .pout(p30), 
      .cout(c[3:1])
    );

    gp4 sec( .gin(g[7:4]) , .pin(p[7:4]), 
      .cin(c[4]), 
      .gout(g74), .pout(p74), 
      .cout(c[7:5])
    );

    gp4 third( .gin(g[11:8]) , .pin(p[11:8]), 
      .cin(c[8]), 
      .gout(g118), .pout(p118), 
      .cout(c[11:9])
    );

    gp4 fourth( .gin(g[15:12]) , .pin(p[15:12]), 
      .cin(c[12]), 
      .gout(g1512), .pout(p1512), 
      .cout(c[15:13])
    );

    gp4 last( .gin({g1512, g118, g74, g30}) , 
      .pin({p1512, p118, p74, p30}), 
      .cin(c[0]), 
      .gout(g150), .pout(p150), 
      .cout({c[12], c[8], c[4]})
    );

    /*
      Get sum values
    */
    for (genvar j = 0; j < 16; j = j + 1) begin
        assign sum[j] = a[j] ^ b[j] ^ c[j];
    end

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
