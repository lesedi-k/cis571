/* Yang Du, ydu24 */
/* Lesedi Kereteletswe, lesedik */

`timescale 1ns / 1ps
`default_nettype none

module lc4_alu(input  wire [15:0] i_insn,
               input wire [15:0]  i_pc,
               input wire [15:0]  i_r1data,
               input wire [15:0]  i_r2data,
               output wire [15:0] o_result);


      wire[15:0] a =    (i_insn[15:12] == 4'd0 || i_insn[15:11] == 5'd9 ||
                              i_insn[15:11] == 5'd25) ? i_pc :
                        i_r1data;

      wire[15:0] b =    (i_insn[15:12] == 4'd0) ? {{7{i_insn[8]}}, i_insn[8:0]} :
                  (     (i_insn[15:12] == 4'd1 && !i_insn[5]) ||
                        (i_insn[15:12] == 4'd10 && i_insn[5:4] == 2'd3) ||
                        (i_insn[15:12] == 4'd5 && !i_insn[5]) ||
                        (i_insn[15:12] == 4'd2 && (i_insn[8:7] == 2'd0 || i_insn[8:7] == 2'd1))
                  ) 
                        ? i_r2data :
                        (i_insn[15:11] == 5'd8 || i_insn[15:12] == 4'd8 ||
                              i_insn[15:11] == 5'd24) ? 16'd0 :
                        i_insn;


      wire[5:0] alu_ctl = (i_insn[15:12] == 4'd0) ? 6'd0 :
                  (i_insn[15:12] == 4'd1 && i_insn[5] == 1'b0) ? {{4'b0},i_insn[4:3]} :
                  (i_insn[15:12] == 4'd1 && i_insn[5] == 1'b1) ? 6'd5 :
                  (i_insn[15:12] == 4'd10 && i_insn[5:4] == 2'd3) ? 6'd4 :
                  (i_insn[15:12] == 4'd5 && i_insn[5] == 1'b0) ? {{4'd2},i_insn[4:3]} :
                  (i_insn[15:12] == 4'd5 && i_insn[5]) ? 6'd12 :
                  (i_insn[15:12] == 4'd6 || i_insn[15:12] == 4'd7) ? 6'd6 :
                  (i_insn[15:12] == 4'd9) ? 6'd32 :
                  (i_insn[15:12] == 4'd13) ? 6'd33 :
                  (i_insn[15:12] == 4'd2) ? {{4'd4}, i_insn[8:7]} :
                  (i_insn[15:12] == 4'd10) ? {{4'd6}, i_insn[5:4]} :
                  (i_insn[15:11] == 5'd8 || i_insn[15:12] == 4'd8 ||
                        i_insn[15:11] == 5'd24) ? 6'd0 :
                  (i_insn[15:11] == 5'd9) ? 6'd34 :
                  (i_insn[15:11] == 5'd25) ? 6'd7 :
                  (i_insn[15:12] == 4'd15) ? 6'd35 :
                  6'd0;


      wire[15:0] add_out;
      wire[15:0] sub_out;
      wire[15:0] div_out;
      wire[15:0] mod_out;

      wire[15:0] add_b =      (alu_ctl[2:0] == 3'd0) ? b :
                        (alu_ctl[2:0] == 3'd2) ? ~b :
                        (alu_ctl[2:0] == 3'd5) ? {{11{b[4]}}, b[4:0]} :
                        (alu_ctl[2:0] == 3'd6) ? {{10{b[5]}}, b[5:0]} :
                        (alu_ctl[2:0] == 3'd7) ? {{5{b[10]}}, b[10:0]} :
                        0;
      
      wire add_cin = (alu_ctl[2:0] == 3'd2) ? 1 :
                  (i_insn[15:12] == 4'd0) ? 1 :
                  (i_insn[15:11] == 5'd25) ? 1 :
                  0;

      cla16 cla(  .a(a),
                  .b(add_b),
                  .cin(add_cin),
                  .sum(add_out));

      lc4_divider my_div(    .i_dividend(a),
                              .i_divisor(b),
                              .o_remainder(mod_out),
                              .o_quotient(div_out));

      wire[15:0] arith_out =     (alu_ctl[2:0] == 3'd0) ? add_out :
                  (alu_ctl[2:0] == 3'd1) ? a * b :
                  (alu_ctl[2:0] == 3'd2) ? add_out :
                  (alu_ctl[2:0] == 3'd3) ? div_out :
                  (alu_ctl[2:0] == 3'd4) ? mod_out :
                  (alu_ctl[2:0] == 3'd5) ? add_out :
                  (alu_ctl[2:0] == 3'd6) ? add_out :
                  (alu_ctl[2:0] == 3'd7) ? add_out :
                  16'd0;

      wire[15:0] logi_out =  (alu_ctl[2:0] == 3'd0) ? a & b :
                  (alu_ctl[2:0] == 3'd1) ? ~a :
                  (alu_ctl[2:0] == 3'd2) ? a | b :
                  (alu_ctl[2:0] == 3'd3) ? a ^ b :
                  (alu_ctl[2:0] == 3'd4) ? a &  {{11{b[4]}}, b[4:0]}:
                  16'd0;

      wire[15:0] b_sext9 = {{9{b[6]}}, b[6:0]};
      wire[15:0] b_usext9 = {9'b0, b[6:0]};

      wire[15:0] comp_out =  (alu_ctl[2:0] == 3'd0) ? (
                        ($signed(a) == $signed(b)) ? 16'd0 :
                        ($signed(a) > $signed(b)) ? 16'd1 :
                        {16{1'b1}}
                  ) :
                  (alu_ctl[2:0] == 3'd1) ? (
                        (a == b) ? 16'd0 :
                        (a > b) ? 16'd1 :
                        {16{1'b1}}
                  ) :
                  (alu_ctl[2:0] == 3'd2) ? (
                        ($signed(a) == $signed(b_sext9)) ? 16'd0 :
                        ($signed(a) > $signed(b_sext9)) ? 16'd1 :
                        {16{1'b1}}
                  ) :
                  (alu_ctl[2:0] == 3'd3) ? (
                        (a == b_usext9) ? 16'd0 :
                        (a > b_usext9) ? 16'd1 :
                        {16{1'b1}}
                  ) :
                  16'd0;
      
      wire signed [15:0] a_signed_shift = $signed(a) >>> b[3:0];

      wire[15:0] shift_out = (alu_ctl[2:0] == 3'd0) ? (
                        a << b[3:0]
                  ) :
                  (alu_ctl[2:0] == 3'd1) ? (
                        a_signed_shift
                  ) :
                  (alu_ctl[2:0] == 3'd2) ? (
                        a >> b[3:0]
                  ) :
                  16'd0;
      
      wire[15:0] const_out = 
                  (alu_ctl[2:0] == 3'd0) ? (
                        {{7{b[8]}}, b[8:0]}
                  ) :
                  (alu_ctl[2:0] == 3'd1) ? (
                        (a & {8'd0, {8{1'b1}}}) | {b[7:0], {8'd0}}
                  ) :
                  (alu_ctl[2:0] == 3'd2) ? (
                        (a & ({1'b1, 15'b0})) | {{b[10:0]}, 4'b0}
                  ) :
                  (alu_ctl[3:0] == 3'd3) ? (
                        ({1'b1, 15'b0} | {8'b0, b[7:0]})
                  ) :
                  16'd0;
      
      assign o_result =  (alu_ctl[5:3] == 3'd0) ? (arith_out) :
                  (alu_ctl[5:3] == 3'd1) ? (logi_out) :
                  (alu_ctl[5:3] == 3'd2) ? (comp_out) :
                  (alu_ctl[5:3] == 3'd3) ? (shift_out) :
                  (alu_ctl[5:3] == 3'd4) ? (const_out) :
                  16'd0;
      
      
endmodule
