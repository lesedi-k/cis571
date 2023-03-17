/* 
      NAMES: Lesedi Kereteletswe, Yang Du
      PENNKEYS: lesedik, ydu24
*/
`timescale 1ns / 1ps

// disable implicit wire declaration
`default_nettype none

module lc4_processor
   (input wire        clk,                // main clock
    input wire         rst, // global reset
    input wire         gwe, // global we for single-step clock
                                    
    output wire [15:0] o_cur_pc, // Address to read from instruction memory
    input wire [15:0]  i_cur_insn, // Output of instruction memory
    output wire [15:0] o_dmem_addr, // Address to read/write from/to data memory
    input wire [15:0]  i_cur_dmem_data, // Output of data memory
    output wire        o_dmem_we, // Data memory write enable
    output wire [15:0] o_dmem_towrite, // Value to write to data memory
   
    output wire [1:0]  test_stall, // Testbench: is this is stall cycle? (don't compare the test values)
    output wire [15:0] test_cur_pc, // Testbench: program counter
    output wire [15:0] test_cur_insn, // Testbench: instruction bits
    output wire        test_regfile_we, // Testbench: register file write enable
    output wire [2:0]  test_regfile_wsel, // Testbench: which register to write in the register file 
    output wire [15:0] test_regfile_data, // Testbench: value to write into the register file
    output wire        test_nzp_we, // Testbench: NZP condition codes write enable
    output wire [2:0]  test_nzp_new_bits, // Testbench: value to write to NZP bits
    output wire        test_dmem_we, // Testbench: data memory write enable
    output wire [15:0] test_dmem_addr, // Testbench: address to read/write memory
    output wire [15:0] test_dmem_data, // Testbench: value read/writen from/to memory

    input wire [7:0]   switch_data, // Current settings of the Zedboard switches
    output wire [7:0]  led_data // Which Zedboard LEDs should be turned on?
    );
   

   // ********PC*********

   wire[15:0] pc;
   wire[15:0] next_pc;

   // PC Register
   Nbit_reg #(16, 16'h8200) pc_reg (.in(next_pc), .out(pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   // ******************************************FETCH***************************************************

   // Relevant wires
   wire [15:0] f_pc_inc; // pc + 1
   wire [15:0] f_insn; // F current insn

   // Increase pc
   cla16 pc_incr (.a(pc), .b(16'd0), .cin(1'b1), .sum(f_pc_inc));

   // Set F insn
   assign f_insn = i_cur_insn;

   // ******************************************DECODE***************************************************
   
   // Relevant wires
   wire [15:0] d_pc;
   wire [15:0] d_pc_inc;
   wire [15:0] d_insn;
   // Decoder wires
   wire [2:0] d_r1_sel, d_r2_sel, d_rd_sel;
   wire d_r1_re, d_r2_re, d_rd_we, d_nzp_we, d_pc_plus_1_select;
   wire d_is_load, d_is_branch, d_is_control_insn;
   // Reg file output wires
   wire [15:0] d_rs, d_rt;
   // Data Mem signals
   wire [15:0] d_dmem_val;
   wire [15:0] d_dmem_we;

   // D phase Registers
   // (!!!! Not sure if default values are set correctly !!!!)
   // (!!!! Load-to-use stalling not implemented yet !!!!)
   Nbit_reg #(16, 16'h8200) d_pc_reg (.in(pc), .out(d_pc), .clk);
   Nbit_reg #(16, 16'h8201) d_pc_inc_reg (.in(f_pc_inc), .out(d_pc_inc), .clk);
   Nbit_reg #(16, 16'b0) d_insn_reg (.in(f_insn), .out(d_insn), .clk);

   // Decoder
   lc4_decoder decode(
         .insn(d_insn),         // instruction
         .r1sel(d_r1_sel),              // rs
         .r1re(d_r1_re),               // does this instruction read from rs?
         .r2sel(d_r2_sel),              // rt
         .r2re(d_r2_re),               // does this instruction read from rt?
         .wsel(d_rd_sel),               // rd
         .regfile_we(d_rd_we),         // does this instruction write to rd?
         .nzp_we(d_nzp_we),             // does this instruction write the NZP bits?
         .select_pc_plus_one(d_pc_plus_1_select), // write PC+1 to the regfile?
         .is_load(d_is_load),            // is this a load instruction?
         .is_store(d_dmem_we),           // is this a store instruction?
         .is_branch(d_is_branch),          // is this a branch instruction?
         .is_control_insn(d_is_control_insn)     // is this a control instruction (JSR, JSRR, RTI, JMPR, JMP, TRAP)?
   );

   // Regfile
      lc4_regfile #(16) regfile( 
      .clk(clk),
      .gwe(gwe),
      .rst(rst),
      .i_rs(d_r1_sel),      // rs selector √
      .o_rs_data(d_rs), // rs contents √
      .i_rt(d_r2_sel),      // rt selector √
      .o_rt_data(d_rt), // rt contents √
      .i_rd(w_rd_sel),      // rd selector √
      .i_wdata(w_dmem_mux_out),   // data to write √
      .i_rd_we(w_rd_we)    // write enable √
   );


   // ************************************* EXECUTE ******************************************

   // Relevant wires
   // TODO: Need to add more wires, such as control signals. I only included some sample ones
   wire [15:0] x_pc;
   wire [15:0] x_pc_inc;
   wire [15:0] x_insn;

   wire [15:0] x_rs;
   wire [15:0] x_rt;

   // X Phase Registers
   // TODO: Need to add more registers as well
   Nbit_reg #(16, 16'h8200) x_pc_reg (.in(d_pc), .out(x_pc), .clk);
   Nbit_reg #(16, 16'h8201) x_pc_inc_reg (.in(d_pc_inc), .out(x_pc_inc), .clk);
   Nbit_reg #(16, 16'b0) x_insn_reg (.in(d_insn), .out(x_insn), .clk);

   Nbit_reg #(16, 16'b0) x_rs_reg (.in(d_rs), .out(x_rs), .clk);
   Nbit_reg #(16, 16'b0) x_rs_reg (.in(d_rt), .out(x_rt), .clk);



   // ************************************* MEMORY ******************************************

   // Relevant wires
   wire [15:0] m_pc;
   wire [15:0] m_pc_inc;
   wire [15:0] m_insn;

   wire [15:0] m_alu_out;
   wire [15:0] m_dmem_out;

   wire m_pc_plus_1_select;
   wire m_is_load;

   wire [2:0] m_rd_sel;
   wire m_rd_we;
   
   wire m_nzp_we;
   wire [2:0] m_nzp_bits;

   wire m_dmem_we;
   wire m_dmem_addr;




   // ************************************* WRITEBACK ******************************************
   
   // Relevant wires
   wire [15:0] w_pc;
   wire [15:0] w_pc_inc;
   wire [15:0] w_insn;
   wire [15:0] w_alu_out;
   wire [15:0] w_dmem_out;
   wire [15:0] w_dmem_mux_out;
   wire w_nzp_we;
   wire [2:0] w_nzp_bits;
   
   wire w_pc_plus_1_select;
   wire w_is_load;

   wire [2:0] w_rd_sel;
   wire w_rd_we;
   
   // W Phase Registers
   Nbit_reg #(16, 16'h8200) w_pc_reg (.in(m_pc), .out(w_pc), .clk);
   Nbit_reg #(16, 16'h8201) w_pc_inc_reg (.in(m_pc_inc), .out(w_pc_inc), .clk);
   Nbit_reg #(16, 16'b0) w_insn_reg (.in(m_insn), .out(w_insn), .clk);
   Nbit_reg #(16, 16'b0) w_alu_out_reg (.in(m_alu_out), .out(w_alu_out), .clk);
   Nbit_reg #(16, 16'b0) w_dmem_out_reg (.in(m_dmem_out), .out(w_dmem_out), .clk);

   Nbit_reg #(1, 1'b0) w_pc_plus_1_select_reg (.in(m_pc_plus_1_select), .out(w_pc_plus_1_select), .clk);
   Nbit_reg #(1, 1'b0) w_is_load_reg (.in(m_is_load), .out(w_is_load), .clk);

   Nbit_reg #(3, 3'b0) w_rd_sel_reg (.in(m_rd_sel), .out(w_rd_sel), .clk);
   Nbit_reg #(1, 1'b0) w_rd_we_reg (.in(m_d_we), .out(w_d_we), .clk);

   Nbit_reg #(1, 1'b0) w_nzp_we_reg (.in(m_nzp_we), .out(w_nzp_we), .clk);
   Nbit_reg #(3, 3'b0) w_nzp_bits_reg (.in(m_nzp_bits), .out(w_nzp_bits), .clk);

   Nbit_reg #(1, 1'b0) w_dmem_we_reg (.in(m_dmem_we), .out(w_dmem_we), .clk);
   Nbit_reg #(16, 16'b0) w_dmem_addr_reg (.in(m_dmem_addr), .out(w_dmem_addr), .clk);
   

   assign w_dmem_mux_out = (w_is_load) ? w_dmem_out:
                        (w_pc_plus_1_select) ? w_pc_inc:
                        w_alu_out;


   // Testing wires
   assign test_cur_pc = w_pc;
   assign test_cur_insn = w_insn;
   assign test_regfile_data = w_dmem_mux_out;   

   assign test_regfile_we = w_rd_we;
   assign test_regfile_wsel = w_rd_sel;

   assign test_nzp_we = w_nzp_we;
   assign test_nzp_new_bits = w_nzp_bits;

   assign test_dmem_data = w_dmem_out;
   assign test_dmem_we = w_dmem_we;
   assign test_dmem_addr = w_dmem_addr;
   assign test_stall = 2'd0;
   assign test_cur_pc = w_pc;





   /* Add $display(...) calls in the always block below to
    * print out debug information at the end of every cycle.
    * 
    * You may also use if statements inside the always block
    * to conditionally print out information.
    *
    * You do not need to resynthesize and re-implement if this is all you change;
    * just restart the simulation.
    */
`ifndef NDEBUG
   always @(posedge gwe) begin
      // $display("%d %h %h %h %h %h", $time, f_pc, d_pc, e_pc, m_pc, test_cur_pc);
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
      // then right-click, and select Radix->Hexadecimal.

      // To see the values of wires within a module, select
      // the module in the hierarchy in the "Scopes" pane.
      // The Objects pane will update to display the wires
      // in that module.

      //$display(); 
   end
`endif
endmodule
