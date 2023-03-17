/*  
 * Yang Du, ydu24
 * Lesedi Kereteletswe, lesedik
 *
 * lc4_regfile.v
 * Implements an 8-register register file parameterized on word size.
 *
 */

`timescale 1ns / 1ps

// Prevent implicit wire declaration
`default_nettype none

module lc4_regfile #(parameter n = 16)
   (input  wire         clk,
    input  wire         gwe,
    input  wire         rst,
    input  wire [  2:0] i_rs,      // rs selector √
    output wire [n-1:0] o_rs_data, // rs contents √
    input  wire [  2:0] i_rt,      // rt selector √
    output wire [n-1:0] o_rt_data, // rt contents √
    input  wire [  2:0] i_rd,      // rd selector √
    input  wire [n-1:0] i_wdata,   // data to write √
    input  wire         i_rd_we    // write enable √
    );


    wire [n-1:0] rd_mux_out[7:0];
    wire [n-1:0] reg_out[7:0];

    genvar i;
    generate
    for (i = 0; i < 8; i = i + 1) begin: rd_mux
        Nbit_reg #(n) one_reg (.in(i_wdata), .out(reg_out[i]), .clk(clk), .we((i_rd == i) && i_rd_we),
            .gwe(gwe), .rst(rst));
    end
    endgenerate

    assign o_rs_data =  (i_rs == 3'd0) ? reg_out[0] :
                        (i_rs == 3'd1) ? reg_out[1] :
                        (i_rs == 3'd2) ? reg_out[2] :
                        (i_rs == 3'd3) ? reg_out[3] :
                        (i_rs == 3'd4) ? reg_out[4] :
                        (i_rs == 3'd5) ? reg_out[5] :
                        (i_rs == 3'd6) ? reg_out[6] :
                        reg_out[7];


    assign o_rt_data =  (i_rt == 3'd0) ? reg_out[0] :
                        (i_rt == 3'd1) ? reg_out[1] :
                        (i_rt == 3'd2) ? reg_out[2] :
                        (i_rt == 3'd3) ? reg_out[3] :
                        (i_rt == 3'd4) ? reg_out[4] :
                        (i_rt == 3'd5) ? reg_out[5] :
                        (i_rt == 3'd6) ? reg_out[6] :
                        reg_out[7];


endmodule
