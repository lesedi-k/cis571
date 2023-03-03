/* TODO: name and PennKeys of all group members here
 *
 * lc4_single.v
 * Implements a single-cycle data path
 *
 */

`timescale 1ns / 1ps

// disable implicit wire declaration
`default_nettype none

module lc4_processor
   (input  wire        clk,                // Main clock
    input  wire        rst,                // Global reset
    input  wire        gwe,                // Global we for single-step clock
   
    output wire [15:0] o_cur_pc,           // Address to read from instruction memory
    input  wire [15:0] i_cur_insn,         // Output of instruction memory
    output wire [15:0] o_dmem_addr,        // Address to read/write from/to data memory; SET TO 0x0000 FOR NON LOAD/STORE INSNS
    input  wire [15:0] i_cur_dmem_data,    // Output of data memory
    output wire        o_dmem_we,          // Data memory write enable
    output wire [15:0] o_dmem_towrite,     // Value to write to data memory

    // Testbench signals are used by the testbench to verify the correctness of your datapath.
    // Many of these signals simply export internal processor state for verification (such as the PC).
    // Some signals are duplicate output signals for clarity of purpose.
    //
    // Don't forget to include these in your schematic!

    output wire [1:0]  test_stall,         // Testbench: is this a stall cycle? (don't compare the test values)
    output wire [15:0] test_cur_pc,        // Testbench: program counter
    output wire [15:0] test_cur_insn,      // Testbench: instruction bits
    output wire        test_regfile_we,    // Testbench: register file write enable
    output wire [2:0]  test_regfile_wsel,  // Testbench: which register to write in the register file 
    output wire [15:0] test_regfile_data,  // Testbench: value to write into the register file
    output wire        test_nzp_we,        // Testbench: NZP condition codes write enable
    output wire [2:0]  test_nzp_new_bits,  // Testbench: value to write to NZP bits
    output wire        test_dmem_we,       // Testbench: data memory write enable
    output wire [15:0] test_dmem_addr,     // Testbench: address to read/write memory
    output wire [15:0] test_dmem_data,     // Testbench: value read/writen from/to memory
   
    input  wire [7:0]  switch_data,        // Current settings of the Zedboard switches
    output wire [7:0]  led_data            // Which Zedboard LEDs should be turned on?
    );

   // By default, assign LEDs to display switch inputs to avoid warnings about
   // disconnected ports. Feel free to use this for debugging input/output if
   // you desire.
   assign led_data = switch_data;

   
   /* DO NOT MODIFY THIS CODE */
   // Always execute one instruction each cycle (test_stall will get used in your pipelined processor)
   assign test_stall = 2'b0; 

   // pc wires attached to the PC register's ports
   wire [15:0]   pc;      // Current program counter (read out from pc_reg)
   wire [15:0]   next_pc; // Next program counter (you compute this and feed it into next_pc)

   // Program counter register, starts at 8200h at bootup
   Nbit_reg #(16, 16'h8200) pc_reg (.in(next_pc), .out(pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   /* END DO NOT MODIFY THIS CODE */


   /*******************************
    * TODO: INSERT YOUR CODE HERE *
    *******************************/
   assign o_cur_pc = pc;

   wire [2:0] r1_sel, r2_sel, w_sel;
   wire r1_re, r2_re, reg_we, nzp_we, pc_plus_1_select;
   wire is_load, is_branch, is_control_insn;

   lc4_decoder decode(
         .insn(i_cur_insn),         // instruction
         .r1sel(r1_sel),              // rs
         .r1re(r1_re),               // does this instruction read from rs?
         .r2sel(r2_sel),              // rt
         .r2re(r2_re),               // does this instruction read from rt?
         .wsel(w_sel),               // rd
         .regfile_we(reg_we),         // does this instruction write to rd?
         .nzp_we(nzp_we),             // does this instruction write the NZP bits?
         .select_pc_plus_one(pc_plus_1_select), // write PC+1 to the regfile?
         .is_load(is_load),            // is this a load instruction?
         .is_store(o_dmem_we),           // is this a store instruction?
         .is_branch(is_branch),          // is this a branch instruction?
         .is_control_insn(is_control_insn)     // is this a control instruction (JSR, JSRR, RTI, JMPR, JMP, TRAP)?
      );
   wire [15:0] rs, rt, alu_out;

   lc4_regfile #(16) regfile( 
      .clk(clk),
      .gwe(gwe),
      .rst(rst),
      .i_rs(r1_sel),      // rs selector √
      .o_rs_data(rs), // rs contents √
      .i_rt(r2_sel),      // rt selector √
      .o_rt_data(rt), // rt contents √
      .i_rd(w_sel),      // rd selector √
      .i_wdata(dmem_mux_out),   // data to write √
      .i_rd_we(reg_we)    // write enable √
   );

   lc4_alu alu(
      .i_insn(i_cur_insn),
      .i_pc(pc),
      .i_r1data(rs),
      .i_r2data(rt),
      .o_result(alu_out)
   );

   wire out;
   wire [2:0] nzp_bits;
   wire [2:0] nzp_reg_out;

   nzp nzp(
      .nzp_we(nzp_we),
      .data(dmem_mux_out),
      .insn(i_cur_insn),
      .out(out),
      .nzp_bits(nzp_bits)
   );

   Nbit_reg #(3, 3'd0) nzp_reg (
      .in(nzp_bits), 
      .out(nzp_reg_out), 
      .clk(clk), 
      .we(nzp_we), 
      .gwe(gwe), 
      .rst(rst)
   );
   

   // Data module   
   wire [15:0] dmem_out;
   wire [15:0] dmem_mux_out;
   
   assign o_dmem_addr = (o_dmem_we | is_load)? alu_out : 0;
   assign o_dmem_towrite = rt;
   assign dmem_out = (o_dmem_we) ? rt : i_cur_dmem_data;
   
   assign dmem_mux_out = (is_load) ? dmem_out:
                        (pc_plus_1_select) ? pc_inc:
                        alu_out;
   

   // branching
   wire [15:0] pc_inc;

   cla16 pc_incr (.a(pc), .b(16'd0), .cin(1'b1), .sum(pc_inc));

   lc4_branch branch(
      .nzp_reg_out(nzp_reg_out),
      .pc(pc),
      .pc_inc(pc_inc),
      .cur_insn(i_cur_insn),
      .rs(rs),
      .is_branch(is_branch),
      .next_pc(next_pc)
   );


   //test plugins
   assign test_cur_pc = pc;
   assign test_cur_insn = i_cur_insn;
   assign test_regfile_data = dmem_mux_out;   

   assign test_regfile_we = reg_we;
   assign test_regfile_wsel = w_sel;
   assign test_nzp_we = nzp_we;
   assign test_dmem_we = o_dmem_we;
   assign test_nzp_new_bits = nzp_bits;

   assign test_dmem_addr = o_dmem_addr;
   assign test_dmem_data = dmem_out;

   /* Add $display(...) calls in the always block below to
    * print out debug information at the end of every cycle.
    *
    * You may also use if statements inside the always block
    * to conditionally print out information.
    *
    * You do not need to resynthesize and re-implement if this is all you change;
    * just restart the simulation.
    * 
    * To disable the entire block add the statement
    * `define NDEBUG
    * to the top of your file.  We also define this symbol
    * when we run the grading scripts.
    */
`ifndef NDEBUG
   always @(posedge gwe) begin
      //$display("%d %h %h %h %h %h", $time, f_pc, d_pc, e_pc, m_pc, test_cur_pc);
      // if (o_dmem_we)
      //   $display("%d STORE %h <= %h", $time, o_dmem_addr, o_dmem_towrite);

      // Start each $display() format string with a %d argument for time
      // it will make the output easier to read.  Use %b, %h, and %d
      // for binary, hex, and decimal output of additional variables.
      // You do not need to add a \n at the end of your format string.
      // $display("%d ...", $time);

      // Try adding a $display() call that prints out the PCs of
      // each pipeline stage in hex.  Then you can easily look up the
      // instructions in the .asm files in test_data.

      // basic if syntax:
      // if (cond) begin
      //    ...;
      //    ...;
      // end

      // Set a breakpoint on the empty $display() below
      // to step through your pipeline cycle-by-cycle.
      // You'll need to rewind the simulation to start
      // stepping from the beginning.

      // You can also simulate for XXX ns, then set the
      // breakpoint to start stepping midway through the
      // testbench.  Use the $time printouts you added above (!)
      // to figure out when your problem instruction first
      // enters the fetch stage.  Rewind your simulation,
      // run it for that many nano-seconds, then set
      // the breakpoint.

      // In the objects view, you can change the values to
      // hexadecimal by selecting all signals (Ctrl-A),
      // then right-click, and select Radix->Hexadecial.

      // To see the values of wires within a module, select
      // the module in the hierarchy in the "Scopes" pane.
      // The Objects pane will update to display the wires
      // in that module.

      //$display();
   end
`endif
endmodule


module nzp(
   input wire nzp_we,
   input wire [15:0]  data,
   input wire [15:0] insn,
   output wire out,
   output wire [2:0] nzp_bits);

   assign nzp_bits = (data[15] == 1) ? 4 : 
   (data == 0) ? 2 : 
   (data > 0) ? 1 : 0;

   //store in register
   //reg [2:0] nzp;
   //assign nzp = nzp_bits;

   //if (nzp_we)
   assign out = (insn[11:9] == nzp_bits) ? 1 : 0;

endmodule


module lc4_branch(
   input wire [2:0] nzp_reg_out,
   input wire [15:0] pc,
   input wire [15:0] pc_inc,
   input wire [15:0] cur_insn, 
   input wire [15:0] rs, 
   input wire is_branch,
   output wire [15:0] next_pc);

   // br_pc wire
   // NZP Br Test
   wire br_test = (cur_insn[15:9] == 7'd1 && nzp_reg_out[0] == 1) ? 1 :
      (cur_insn[15:9] == 7'd2 && nzp_reg_out[1] == 1) ? 1 :
      (cur_insn[15:9] == 7'd3 && (nzp_reg_out[1] == 1 || nzp_reg_out[0] == 1)) ? 1 :
      (cur_insn[15:9] == 7'd4 && (nzp_reg_out[2] == 1)) ? 1 :
      (cur_insn[15:9] == 7'd5 && (nzp_reg_out[2] == 1 || nzp_reg_out[0] == 1)) ? 1 :
      (cur_insn[15:9] == 7'd6 && (nzp_reg_out[2] == 1 || nzp_reg_out[1] == 1)) ? 1 :
      (cur_insn[15:9] == 7'd7 && (nzp_reg_out != 3'd0)) ? 1 :
      0;
   
   wire [15:0] br_dest_sum;
   cla16 br_adder (.a(pc_inc), .b({{7{cur_insn[8]}}, cur_insn[8:0]}), .cin(1'b0), .sum(br_dest_sum));

   wire [15:0] br_pc = br_test ? br_dest_sum : pc_inc;

   // trap_pc wire
   wire [15:0] trap_pc = {{8{1'b0}}, cur_insn[7:0] | 16'h8000};

   // jmp_pc wire
   wire [15:0] jmp_pc;
   cla16 jmp_adder (.a(pc_inc), .b({{5{cur_insn[10]}}, cur_insn[10:0]}), .cin(1'b0), .sum(jmp_pc));
   
   // jsr_pc wire
   wire [15:0] jsr_pc = (pc & 16'h8000) | (cur_insn[10:0] << 4);

   assign next_pc = is_branch ? br_pc :
      (cur_insn[15:12] == 4'b1111) ? trap_pc :
      (cur_insn[15:11] == 5'b11000 || cur_insn[15:11] == 5'b01000) ? rs :
      (cur_insn[15:11] == 5'b11001) ? jmp_pc:
      (cur_insn[15:11] == 5'b01001) ? jsr_pc:
      pc_inc;

endmodule