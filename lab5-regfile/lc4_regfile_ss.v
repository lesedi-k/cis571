`timescale 1ns / 1ps

// Prevent implicit wire declaration
`default_nettype none

/* 8-register, n-bit register file with
 * four read ports and two write ports
 * to support two pipes.
 * 
 * If both pipes try to write to the
 * same register, pipe B wins.
 * 
 * Inputs should be bypassed to the outputs
 * as needed so the register file returns
 * data that is written immediately
 * rather than only on the next cycle.
 */
module lc4_regfile_ss #(parameter n = 16)
   (input  wire         clk,
    input  wire         gwe,
    input  wire         rst,

    input  wire [  2:0] i_rs_A,      // pipe A: rs selector
    output wire [n-1:0] o_rs_data_A, // pipe A: rs contents
    input  wire [  2:0] i_rt_A,      // pipe A: rt selector
    output wire [n-1:0] o_rt_data_A, // pipe A: rt contents

    input  wire [  2:0] i_rs_B,      // pipe B: rs selector
    output wire [n-1:0] o_rs_data_B, // pipe B: rs contents
    input  wire [  2:0] i_rt_B,      // pipe B: rt selector
    output wire [n-1:0] o_rt_data_B, // pipe B: rt contents

    input  wire [  2:0]  i_rd_A,     // pipe A: rd selector
    input  wire [n-1:0]  i_wdata_A,  // pipe A: data to write
    input  wire          i_rd_we_A,  // pipe A: write enable

    input  wire [  2:0]  i_rd_B,     // pipe B: rd selector
    input  wire [n-1:0]  i_wdata_B,  // pipe B: data to write
    input  wire          i_rd_we_B   // pipe B: write enable
    );

   wire [n-1:0] reg_out[7:0];
   wire [n-1:0] in[7:0];

   genvar j;
   generate
   for (j = 0; j < 8; j = j + 1) begin: reg_out_mux
     assign in[j] = ((i_rd_B == j) && i_rd_we_B)  ? i_wdata_B :
                     ((i_rd_A == j) && i_rd_we_A) ? i_wdata_A :
                     i_wdata_B;
   end
   endgenerate

   genvar i;
   generate
   for (i = 0; i < 8; i = i + 1) begin: rd_mux
      Nbit_reg #(n) one_reg (.in(in[i]), .out(reg_out[i]), 
         .clk(clk), .we(((i_rd_B == i) && i_rd_we_B) || ((i_rd_A == i) && i_rd_we_A)),
         .gwe(gwe), .rst(rst));
   end
   endgenerate

   
   //bypass to output
   assign o_rs_data_A = ((i_rs_A == i_rd_B) && i_rd_we_B) ? i_wdata_B :
                     ((i_rs_A == i_rd_A) && i_rd_we_A) ? i_wdata_A :
                     (i_rs_A == 3'd0) ? reg_out[0] :
                     (i_rs_A == 3'd1) ? reg_out[1] :
                     (i_rs_A == 3'd2) ? reg_out[2] :
                     (i_rs_A == 3'd3) ? reg_out[3] :
                     (i_rs_A == 3'd4) ? reg_out[4] :
                     (i_rs_A == 3'd5) ? reg_out[5] :
                     (i_rs_A == 3'd6) ? reg_out[6] :
                     reg_out[7];


   assign o_rt_data_A = ((i_rt_A == i_rd_B) && i_rd_we_B) ? i_wdata_B :
                      ((i_rt_A == i_rd_A) && i_rd_we_A) ? i_wdata_A :
                     (i_rt_A == 3'd0) ? reg_out[0] :
                     (i_rt_A == 3'd1) ? reg_out[1] :
                     (i_rt_A == 3'd2) ? reg_out[2] :
                     (i_rt_A == 3'd3) ? reg_out[3] :
                     (i_rt_A == 3'd4) ? reg_out[4] :
                     (i_rt_A == 3'd5) ? reg_out[5] :
                     (i_rt_A == 3'd6) ? reg_out[6] :
                     reg_out[7];
         
   assign o_rs_data_B = ((i_rs_B == i_rd_B) && i_rd_we_B) ? i_wdata_B :
                        ((i_rs_B == i_rd_A) && i_rd_we_A) ? i_wdata_A :
                        (i_rs_B == 3'd0) ? reg_out[0] :
                        (i_rs_B == 3'd1) ? reg_out[1] :
                        (i_rs_B == 3'd2) ? reg_out[2] :
                        (i_rs_B == 3'd3) ? reg_out[3] :
                        (i_rs_B == 3'd4) ? reg_out[4] :
                        (i_rs_B == 3'd5) ? reg_out[5] :
                        (i_rs_B == 3'd6) ? reg_out[6] :
                        reg_out[7];

   //something is off here
   assign o_rt_data_B = ((i_rt_B == i_rd_B) && i_rd_we_B) ? i_wdata_B :
                        ((i_rt_B == i_rd_A) && i_rd_we_A) ? i_wdata_A :
                        (i_rt_B == 3'd0) ? reg_out[0] :
                        (i_rt_B == 3'd1) ? reg_out[1] :
                        (i_rt_B == 3'd2) ? reg_out[2] :
                        (i_rt_B == 3'd3) ? reg_out[3] :
                        (i_rt_B == 3'd4) ? reg_out[4] :
                        (i_rt_B == 3'd5) ? reg_out[5] :
                        (i_rt_B == 3'd6) ? reg_out[6] :
                        reg_out[7];

endmodule
