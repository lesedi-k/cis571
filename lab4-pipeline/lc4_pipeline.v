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

   /** assignments from prev HW **/
   assign led_data = switch_data;

   
   /* DO NOT MODIFY THIS CODE */
   // Always execute one instruction each cycle (test_stall will get used in your pipelined processor)
   //assign test_stall = 2'b0; 

// ******************************************FETCH***************************************************
   
   // ********PC*********

   wire[15:0] pc;
   wire[15:0] next_pc;

   // PC Register
   Nbit_reg #(16, 16'h8200) pc_reg (.in(next_pc), .out(pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   // Relevant wires
   wire [15:0] f_pc_inc; // pc + 1
   wire [15:0] f_insn; // F current insn

   assign next_pc = pc + 16'b1;
   

   // Increase pc
   //cla16 pc_incr (.a(pc), .b(16'd0), .cin(1'b1), .sum(f_pc_inc));

   // Set F insn
   assign o_cur_pc = pc;
   //assign f_insn = i_cur_insn;
   Nbit_reg #(16, 16'b0) f_insn_reg (.in(i_cur_insn), .out(f_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));



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
   wire [15:0] d_dmem_val, d_dmem_addr;
   wire d_dmem_we;

   // D phase Registers
   // (!!!! Not sure if default values are set correctly !!!!)
   // (!!!! Load-to-use stalling not implemented yet !!!!)
   Nbit_reg #(16, 16'h8200) d_pc_reg (.in(pc), .out(d_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h8201) d_pc_inc_reg (.in(f_pc_inc), .out(d_pc_inc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) d_insn_reg (.in(f_insn), .out(d_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   //TODO: will need further later
   Nbit_reg #(16, 16'h0) d_dmem_data_reg (.in(d_rt), .out(d_dmem_val), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

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
      .i_rd(d_rd_sel),      // rd selector √
      .i_wdata(d_dmem_val),   // data to write √
      .i_rd_we(d_rd_we)    // write enable √
   );


// ************************************* EXECUTE ******************************************

   // Relevant wires
   wire [15:0] x_pc;
   wire [15:0] x_pc_inc;
   wire [15:0] x_insn;

   wire [15:0] x_rs, x_rt, x_rd;

   wire [15:0] x_dmem_addr, x_dmem_val;
   wire x_dmem_we;

   // X wires
   wire [2:0] x_r1_sel, x_r2_sel, x_rd_sel; // NOT COPIED OVER RN
  // wire x_r1_re, x_r2_re;
   wire x_rd_we, x_nzp_we, x_pc_plus_1_select; 
   wire x_is_load, x_is_branch, x_is_control_insn;


   //NZP wires
   wire x_nzp_out;
   wire [2:0] x_nzp_bits;
   wire [2:0] x_nzp_reg_out;

   //R1 mux for WX and MX bypassing
   wire [15:0] r1_mux_out, r2_mux_out;

   // Storing D values to X Phase Registers
   Nbit_reg #(16, 16'h8200) x_pc_reg (.in(d_pc), .out(x_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h8201) x_pc_inc_reg (.in(d_pc_inc), .out(x_pc_inc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) x_insn_reg (.in(d_insn), .out(x_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(16, 16'b0) x_rs_reg (.in(d_rs), .out(x_rs), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) x_rt_reg (.in(d_rt), .out(x_rt), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); 

   Nbit_reg #(3, 3'b0) x_r1_sel_reg (.in(d_r1_sel), .out(x_r1_sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'b0) x_r2_sel_reg (.in(d_r2_sel), .out(x_r2_sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'b0) x_rd_sel_reg (.in(d_rd_sel), .out(x_rd_sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0) x_rd_we_reg (.in(d_rd_we), .out(x_rd_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));


   Nbit_reg #(1, 1'b0) x_pc_plus_1_select_reg (.in(d_pc_plus_1_select), .out(x_pc_plus_1_select), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0) x_is_load_reg (.in(d_is_load), .out(x_is_load), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0) x_is_branch_reg (.in(d_is_branch), .out(x_is_branch), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0) x_is_control_reg (.in(d_is_control_insn), .out(x_is_control_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(1, 1'b0) x_nzp_we_reg (.in(d_nzp_we), .out(x_nzp_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
 
   Nbit_reg #(1, 1'b0) x_dmem_we_reg (.in(d_dmem_we), .out(x_dmem_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h0) x_dmem_addr_reg (.in(d_dmem_addr), .out(x_dmem_addr), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h0) x_dmem_data_reg (.in(d_dmem_val), .out(x_dmem_val), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   
   //pass on nzp out
   

   //mx, wx
   assign r1_mux_out = (x_r1_sel == m_rd_sel) ? m_rd :
                        (x_r1_sel == w_rd_sel) ? w_rd :
                        x_rs;


   assign r2_mux_out = (x_r2_sel == m_rd_sel) ? m_rd :
                        (x_r2_sel == w_rd_sel) ? w_rd :
                        x_rt;

   //ALU
   lc4_alu alu(
         .i_insn(x_insn), //CHECK: might be x_pc_reg
         .i_pc(x_pc),
         .i_r1data(r1_mux_out),
         .i_r2data(r2_mux_out),
         .o_result(x_rd)
      );

   assign d_dmem_addr = (d_is_load | d_dmem_we ) ? x_rd : 16'b0;


   nzp nzp(
      .nzp_we(x_nzp_we),
      .data(x_dmem_addr),
      .insn(x_insn),
      .out(x_nzp_out),
      .nzp_bits(x_nzp_bits)
   );

   Nbit_reg #(3, 3'b0) nzp_reg (
      .in(x_nzp_bits), 
      .out(x_nzp_reg_out), 
      .clk(clk), 
      .we(x_nzp_we), 
      .gwe(gwe), 
      .rst(rst)
   );

   

   // lc4_branch branch(
   //    .nzp_reg_out(x_nzp_reg_out),
   //    .pc(x_pc),
   //    .pc_inc(x_pc_inc),
   //    .cur_insn(i_cur_insn),
   //    .rs(x_rs),
   //    .is_branch(x_is_branch),
   //    .next_pc(next_pc)
   // );

// ************************************* MEMORY ******************************************

   // Relevant wires
   wire [15:0] m_pc;
   wire [15:0] m_pc_inc;
   wire [15:0] m_insn;

   //wire [15:0] m_alu_out;
   wire [15:0] m_dmem_addr;
   wire m_dmem_we;
   //wire [15:0] m_dmem_val;

   wire [15:0] m_rs, m_rt, m_rd;
   wire [2:0] m_r1_sel, m_r2_sel, m_rd_sel;
   wire m_rd_we;

   wire m_pc_plus_1_select;
   wire m_is_load;
   
   wire m_nzp_we;
   wire [2:0] m_nzp_bits;
   wire [2:0] m_nzp_reg_out;

   Nbit_reg #(16, 16'h8200) m_pc_reg (.in(x_pc), .out(m_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h8201) m_pc_inc_reg (.in(x_pc_inc), .out(m_pc_inc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) m_insn_reg (.in(x_insn), .out(m_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(1, 1'b0) m_pc_plus_1_select_reg (.in(x_pc_plus_1_select), .out(m_pc_plus_1_select), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0) m_is_load_reg (.in(x_is_load), .out(m_is_load), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   //Nbit_reg #(1, 1'b0) m_is_branch_reg (.in(x_is_branch), .out(x_is_branch), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   //Nbit_reg #(1, 1'b0) m_is_control_reg (.in(x_is_control_insn), .out(x_is_control_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));


   Nbit_reg #(16, 16'b0) m_rs_reg (.in(x_rs), .out(m_rs), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) m_rt_reg (.in(x_rt), .out(m_rt), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); 
   Nbit_reg #(16, 16'b0) m_rd_reg (.in(x_rd), .out(m_rd), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); 

   Nbit_reg #(3, 3'b0) m_r1_sel_reg (.in(x_r1_sel), .out(m_r1_sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'b0) m_r2_sel_reg (.in(x_r2_sel), .out(m_r2_sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'b0) m_rd_sel_reg (.in(x_rd_sel), .out(m_rd_sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0) m_rd_we_reg (.in(x_rd_we), .out(m_rd_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(1, 1'b0) m_nzp_we_reg (.in(x_nzp_we), .out(m_nzp_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'b0) m_nzp_bit_reg (.in(x_nzp_bits), .out(m_nzp_bits), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'b0) m_nzp_reg_out_reg (.in(x_nzp_reg_out), .out(m_nzp_reg_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); //!!! Not sure is this is redundant

   Nbit_reg #(1, 1'b0) m_dmem_we_reg (.in(x_dmem_we), .out(o_dmem_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h0) m_dmem_addr_reg (.in(x_dmem_addr), .out(o_dmem_addr), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   
   //Nbit_reg #(16, 16'h0) m_dmem_data_reg (.in(x_dmem_val), .out(m_dmem_val), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h0) m_dmem_data_reg (.in(x_dmem_val), .out(o_dmem_towrite), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   //DATA MODULE
   wire [15:0] m_alu_out, m_dmem_out;
   wire [15:0] m_dmem_mux_out;
   
   assign m_alu_out = (m_dmem_we | m_is_load)? x_rd : 0;
   assign o_dmem_towrite = x_rt;
   assign m_dmem_out = (m_dmem_we) ? m_rt : i_cur_dmem_data;
   
   assign m_dmem_mux_out = (m_is_load) ? m_dmem_out:
                        (m_pc_plus_1_select) ? m_pc_inc:
                        m_alu_out;

   
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

   wire [15:0] w_rs, w_rt, w_rd;
   wire [2:0] w_r1_sel, w_r2_sel, w_rd_sel;
   wire w_rd_we;

   //TODO: Make wires for this
   //wire w_dmem_we;
   //wire [15:0] w_dmem_addr;
   
   // W Phase Registers
   Nbit_reg #(16, 16'h8200) w_pc_reg (.in(m_pc), .out(w_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h8201) w_pc_inc_reg (.in(m_pc_inc), .out(w_pc_inc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) w_insn_reg (.in(m_insn), .out(w_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   
   Nbit_reg #(16, 16'b0) w_alu_out_reg (.in(m_alu_out), .out(w_alu_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   
   Nbit_reg #(16, 16'b0) w_dmem_out_reg (.in(m_dmem_out), .out(w_dmem_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) w_dmem_mux_out_reg (.in(m_dmem_mux_out), .out(w_dmem_mux_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));


   Nbit_reg #(1, 1'b0) w_pc_plus_1_select_reg (.in(m_pc_plus_1_select), .out(w_pc_plus_1_select), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0) w_is_load_reg (.in(m_is_load), .out(w_is_load), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(16, 16'b0) w_rs_reg (.in(m_rs), .out(w_rs), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) w_rt_reg (.in(m_rt), .out(w_rt), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); 
   Nbit_reg #(16, 16'b0) w_rd_reg (.in(m_rd), .out(w_rd), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); 

   Nbit_reg #(3, 3'b0) w_r1_sel_reg (.in(m_r1_sel), .out(w_r1_sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'b0) w_r2_sel_reg (.in(m_r2_sel), .out(w_r2_sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'b0) w_rd_sel_reg (.in(m_rd_sel), .out(w_rd_sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0) w_rd_we_reg (.in(m_rd_we), .out(w_rd_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(1, 1'b0) w_nzp_we_reg (.in(m_nzp_we), .out(w_nzp_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'b0) w_nzp_bits_reg (.in(m_nzp_bits), .out(w_nzp_bits), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
  
   //Nbit_reg #(16, 16'h0) w_dmem_data_reg (.in(m_dmem_val), .out(o_dmem_towrite), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));



   //Nbit_reg #(1, 1'b0) w_dmem_we_reg (.in(m_dmem_we), .out(w_dmem_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   //Nbit_reg #(16, 16'b0) w_dmem_addr_reg (.in(m_dmem_addr), .out(w_dmem_addr), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   

   assign w_dmem_mux_out = (w_is_load) ? w_dmem_out:
                        (w_pc_plus_1_select) ? w_pc_inc:
                        w_alu_out;


// ************************************* TESTING WIRES ******************************************

   assign test_stall = (m_insn == 0) ? 2 : 0;

   assign test_cur_insn = m_insn;

   assign test_regfile_we = m_rd_we;
   assign test_regfile_wsel = m_rd_sel;

   assign test_nzp_we = m_nzp_we;

   assign test_dmem_data = o_dmem_towrite;
   assign test_dmem_we = o_dmem_we;
   assign test_dmem_addr = o_dmem_addr;

   //TO FIX
   assign test_cur_pc = w_pc;
   assign test_nzp_new_bits = m_nzp_bits;
   assign test_regfile_data = x_rd;   

   // assign test_cur_pc = pc;
   // assign test_cur_insn = i_cur_insn;
   // assign test_regfile_data = dmem_mux_out;   

   // assign test_regfile_we = reg_we;
   // assign test_regfile_wsel = w_sel;

   // assign test_nzp_we = nzp_we;
   // assign test_nzp_new_bits = nzp_bits;


   //assign test_dmem_data = dmem_out;



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

module nzp(
   input wire nzp_we,
   input wire [15:0]  data,
   input wire [15:0] insn,
   output wire out,
   output wire [2:0] nzp_bits);

   assign nzp_bits = (data[15] == 1) ? 4 : 
   (data == 0) ? 2 : 
   (data > 0) ? 1 : 0;

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