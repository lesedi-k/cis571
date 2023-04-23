`timescale 1ns / 1ps

// Prevent implicit wire declaration
`default_nettype none

module lc4_processor(input wire         clk,             // main clock
                     input wire         rst,             // global reset
                     input wire         gwe,             // global we for single-step clock

                     output wire [15:0] o_cur_pc,        // address to read from instruction memory
                     input wire [15:0]  i_cur_insn_A,    // output of instruction memory (pipe A)
                     input wire [15:0]  i_cur_insn_B,    // output of instruction memory (pipe B)

                     output wire [15:0] o_dmem_addr,     // address to read/write from/to data memory
                     input wire [15:0]  i_cur_dmem_data, // contents of o_dmem_addr
                     output wire        o_dmem_we,       // data memory write enable
                     output wire [15:0] o_dmem_towrite,  // data to write to o_dmem_addr if we is set

                     // testbench signals (always emitted from the WB stage)
                     output wire [ 1:0] test_stall_A,        // is this a stall cycle?  (0: no stall,
                     output wire [ 1:0] test_stall_B,        // 1: pipeline stall, 2: branch stall, 3: load stall)

                     output wire [15:0] test_cur_pc_A,       // program counter
                     output wire [15:0] test_cur_pc_B,
                     output wire [15:0] test_cur_insn_A,     // instruction bits
                     output wire [15:0] test_cur_insn_B,
                     output wire        test_regfile_we_A,   // register file write-enable
                     output wire        test_regfile_we_B,
                     output wire [ 2:0] test_regfile_wsel_A, // which register to write
                     output wire [ 2:0] test_regfile_wsel_B,
                     output wire [15:0] test_regfile_data_A, // data to write to register file
                     output wire [15:0] test_regfile_data_B,
                     output wire        test_nzp_we_A,       // nzp register write enable
                     output wire        test_nzp_we_B,
                     output wire [ 2:0] test_nzp_new_bits_A, // new nzp bits
                     output wire [ 2:0] test_nzp_new_bits_B,
                     output wire        test_dmem_we_A,      // data memory write enable
                     output wire        test_dmem_we_B,
                     output wire [15:0] test_dmem_addr_A,    // address to read/write from/to memory
                     output wire [15:0] test_dmem_addr_B,
                     output wire [15:0] test_dmem_data_A,    // data to read/write from/to memory
                     output wire [15:0] test_dmem_data_B,

                     // zedboard switches/display/leds (ignore if you don't want to control these)
                     input  wire [ 7:0] switch_data,         // read on/off status of zedboard's 8 switches
                     output wire [ 7:0] led_data             // set on/off status of zedboard's 8 leds
                     );



// ****************************************** FETCH ***************************************************

   // PC wires

   wire[15:0] f_pc;
   wire[15:0] f_next_pc;

   // PC Register
   Nbit_reg #(16, 16'h8200) pc_reg (.in(f_next_pc), .out(f_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   // Other wires
   wire [15:0] f_pc_plus_1;
   wire [15:0] f_pc_plus_2;
   wire [15:0] fA_insn;
   wire [15:0] fB_insn;

   // Post-stall-check wires
   wire [15:0] f_psc_pc;
   wire [15:0] f_psc_pc_plus_1;
   wire [15:0] f_psc_pc_plus_2;
   wire [15:0] fA_psc_insn;
   wire [15:0] fB_psc_insn;


   // Increase pc
   cla16 pc_incr_1 (.a(f_pc), .b(16'd0), .cin(1'b1), .sum(f_pc_plus_1));
   cla16 pc_incr_2 (.a(f_pc), .b(16'd1), .cin(1'b1), .sum(f_pc_plus_2));

   // Assign next pc
   assign f_next_pc =   case_1_stall ? f_pc :
                        (case_2_stall | case_3_stall | case_4_stall) ? f_pc_plus_1 : 
                        f_pc_plus_2;

   // Set F insns
   assign o_cur_pc = f_pc;
   assign fA_insn = i_cur_insn_A;
   assign fB_insn = i_cur_insn_B;

   // Stall check
   assign f_psc_pc =          case_1_stall ? dA_pc :
                              (case_2_stall | case_3_stall | case_4_stall) ? dB_pc : 
                              f_pc;

   assign f_psc_pc_plus_1 =   case_1_stall ? dA_pc_plus_1 :
                              (case_2_stall | case_3_stall | case_4_stall) ? dB_pc_plus_1 : 
                              f_pc_plus_1;

   assign f_psc_pc_plus_2 =   case_1_stall ? dB_pc_plus_1 :
                              (case_2_stall | case_3_stall | case_4_stall) ? f_pc_plus_1 : 
                              f_pc_plus_2;

   assign fA_psc_insn =       case_1_stall ? dA_insn :
                              (case_2_stall | case_3_stall | case_4_stall) ? dB_insn : 
                              fA_insn;

   assign fB_psc_insn =       case_1_stall ? dB_insn :
                              (case_2_stall | case_3_stall | case_4_stall) ? fA_insn : 
                              fB_insn;


// ****************************************** DECODE A ***************************************************

   // PC/insn wires
   wire [15:0] dA_pc;
   wire [15:0] dA_pc_plus_1;
   wire [15:0] dA_insn;

   // Decoder wires
   wire [2:0] dA_r1_sel, dA_r2_sel, dA_rd_sel;
   wire dA_r1_re, dA_r2_re, dA_rd_we, dA_nzp_we, dA_pc_plus_1_select;
   wire dA_is_load, dA_is_branch, dA_is_control_insn, dA_dmem_we;

   // Reg file output wires
   wire [15:0] dA_rs, dA_rt;

   // Stalls
   wire case_1_stall;
   wire case_2_stall;
   wire case_3_stall;
   wire case_4_stall;

   // Post stall check wires
   wire dA_psc_is_load;
   wire dA_psc_is_branch;
   wire dA_psc_is_control_insn;
   wire dA_psc_dmem_we;
   wire dA_psc_rd_we;


   // D.A phase registers
   Nbit_reg #(16, 16'h0000) dA_pc_reg (.in(f_psc_pc), .out(dA_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h8201) dA_pc_inc_reg (.in(f_psc_pc_plus_1), .out(dA_pc_plus_1), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) dA_insn_reg (.in(fA_psc_insn), .out(dA_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   // Decoder
   lc4_decoder dA_decode(
      .insn(dA_insn),                        // instruction
      .r1sel(dA_r1_sel),                     // rs
      .r1re(dA_r1_re),                       // does this instruction read from rs?
      .r2sel(dA_r2_sel),                     // rt
      .r2re(dA_r2_re),                       // does this instruction read from rt?
      .wsel(dA_rd_sel),                      // rd
      .regfile_we(dA_rd_we),                 // does this instruction write to rd?
      .nzp_we(dA_nzp_we),                    // does this instruction write the NZP bits?
      .select_pc_plus_one(dA_pc_plus_1_select), // write PC+1 to the regfile?
      .is_load(dA_is_load),                  // is this a load instruction?
      .is_store(dA_dmem_we),                 // is this a store instruction?
      .is_branch(dA_is_branch),              // is this a branch instruction?
      .is_control_insn(dA_is_control_insn)   // is this a control instruction (JSR, JSRR, RTI, JMPR, JMP, TRAP)?
   );

   // Regfile (Shared)
   lc4_regfile_ss dAB_regfile (
      .clk(clk),
      .gwe(gwe),
      .rst(rst),

      .i_rs_A(dA_r1_sel),
      .o_rs_data_A(dA_rs),
      .i_rt_A(dA_r2_sel),
      .o_rt_data_A(dA_rt),

      .i_rs_B(dB_r1_sel),
      .o_rs_data_B(dB_rs),
      .i_rt_B(dB_r2_sel),
      .o_rt_data_B(dB_rt),

      .i_rd_A(wA_rd_sel),
      .i_wdata_A(wA_dmem_mux_out),
      .i_rd_we_A(wA_rd_we),

      .i_rd_B(wB_rd_sel),
      .i_wdata_B(wB_dmem_mux_out),
      .i_rd_we_B(wB_rd_we)
   );


   // Case 1 stall
   wire dep_dA_rs_xA_rd = (!xA_load_use_stall) && xA_is_load && dA_r1_re && xA_rd_sel == dA_r1_sel && // Vanilla
                              !(!(xB_load_use_stall || xB_ss_stall) && xB_rd_we && xB_rd_sel == dA_r1_sel); // Precedence edge case 
   wire dep_dA_rt_xA_rd = (!xA_load_use_stall) && (!dA_dmem_we) && xA_is_load && dA_r2_re && xA_rd_sel == dA_r2_sel && // Vanilla
                              !(!(xB_load_use_stall || xB_ss_stall) && xB_rd_we && xB_rd_sel == dA_r2_sel); // Precedence edge case
   wire dep_dA_rs_xB_rd = !(xB_load_use_stall || xB_ss_stall) && xB_is_load && dA_r1_re && xB_rd_sel == dA_r1_sel;
   wire dep_dA_rt_xB_rd = !(xB_load_use_stall || xB_ss_stall) && (!dA_dmem_we) && xB_is_load && dA_r2_re && xB_rd_sel == dA_r2_sel;

   assign case_1_stall = dep_dA_rs_xA_rd | dep_dA_rt_xA_rd | dep_dA_rs_xB_rd | dep_dA_rt_xB_rd;

   // Case 2 stall
   wire dep_dB_rs_xA_rd = (!xA_load_use_stall) && xA_is_load && dB_r1_re && xA_rd_sel == dB_r1_sel && // Vanilla
                              !((xB_rd_we && xB_rd_sel == dB_r1_sel) || (dA_rd_we && dA_rd_sel == dB_r1_sel)); // Precedence edge case
   wire dep_dB_rt_xA_rd = (!xA_load_use_stall) && (!dB_dmem_we) && xA_is_load && dB_r2_re && xA_rd_sel == dB_r2_sel &&
                              !((!(xB_load_use_stall || xB_ss_stall) && xB_rd_we && xB_rd_sel == dB_r2_sel) || (dA_rd_we && dA_rd_sel == dB_r2_sel));
   wire dep_dB_rs_xB_rd = !(xB_load_use_stall || xB_ss_stall) && xB_is_load && dB_r1_re && xB_rd_sel == dB_r1_sel &&
                              !(!(xB_load_use_stall || xB_ss_stall) && dA_rd_we && dA_rd_sel == dB_r1_sel);
   wire dep_dB_rt_xB_rd = !(xB_load_use_stall || xB_ss_stall) && (!dB_dmem_we) && xB_is_load && dB_r2_re && xB_rd_sel == dB_r2_sel &&
                              !(dA_rd_we && dA_rd_sel == dB_r2_sel);   

   assign case_2_stall = dep_dB_rs_xA_rd | dep_dB_rt_xA_rd | dep_dB_rs_xB_rd | dep_dB_rt_xB_rd;

   // Case 3 SS stall
   wire dep_A_rd_B_rs = (dA_rd_we && dB_r1_re && dA_rd_sel == dB_r1_sel);
   wire dep_A_rd_B_rt = (!dB_dmem_we) && (dA_rd_we && dB_r2_re && dA_rd_sel == dB_r2_sel);

   assign case_3_stall = dep_A_rd_B_rs | dep_A_rd_B_rt;

   // Case 4 stall
   assign case_4_stall = (dA_is_load | dA_dmem_we) & (dB_is_load | dB_dmem_we);

   // Stall check
   assign dA_psc_is_load = (case_1_stall) ? 1'b0 : dA_is_load;
   assign dA_psc_is_branch = (case_1_stall) ? 1'b0 : dA_is_branch;
   assign dA_psc_is_control_insn = (case_1_stall) ? 1'b0 : dA_is_control_insn;
   assign dA_psc_dmem_we = (case_1_stall) ? 1'b0 : dA_dmem_we;
   assign dA_psc_rd_we = (case_1_stall) ? 1'b0 : dA_rd_we;


// ************************************* EXECUTE A ******************************************

   // Wires
   wire [15:0] xA_pc;
   wire [15:0] xA_pc_plus_1;
   wire [15:0] xA_insn;

   wire [15:0] xA_rs, xA_rt;

   wire xA_dmem_we;

   wire [2:0] xA_r1_sel, xA_r2_sel, xA_rd_sel;
   wire xA_rd_we, xA_nzp_we, xA_pc_plus_1_select; 
   wire xA_is_load, xA_is_branch, xA_is_control_insn;

   wire xA_r1_re;
   wire xA_r2_re;

   wire [15:0] xA_alu_out;

   // R1 mux for WX and MX bypassing
   wire [15:0] xA_r1_bp_out, xA_r2_bp_out;

   // NZP wires
   wire [2:0] xA_nzp_bits;
   wire [2:0] xA_nzp_reg_out;

   // Stall
   wire xA_load_use_stall;


   // X.A Phase Registers
   Nbit_reg #(16, 16'h0000) xA_pc_reg (.in(dA_pc), .out(xA_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h8201) xA_pc_plus_1_reg (.in(dA_pc_plus_1), .out(xA_pc_plus_1), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) xA_insn_reg (.in(dA_insn), .out(xA_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));


   Nbit_reg #(16, 16'b0) xA_rs_reg (.in(dA_rs), .out(xA_rs), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) xA_rt_reg (.in(dA_rt), .out(xA_rt), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); 

   Nbit_reg #(3, 3'b0) xA_r1_sel_reg (.in(dA_r1_sel), .out(xA_r1_sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'b0) xA_r2_sel_reg (.in(dA_r2_sel), .out(xA_r2_sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'b0) xA_rd_sel_reg (.in(dA_rd_sel), .out(xA_rd_sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0) xA_rd_we_reg (.in(dA_rd_we), .out(xA_rd_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));


   Nbit_reg #(1, 1'b0) xA_pc_plus_1_select_reg (.in(dA_pc_plus_1_select), .out(xA_pc_plus_1_select), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0) xA_is_load_reg (.in(dA_is_load), .out(xA_is_load), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0) xA_is_branch_reg (.in(dA_is_branch), .out(xA_is_branch), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0) xA_is_control_reg (.in(dA_is_control_insn), .out(xA_is_control_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(1, 1'b0) xA_nzp_we_reg (.in(dA_nzp_we), .out(xA_nzp_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(1, 1'b0) xA_dmem_we_reg (.in(dA_dmem_we), .out(xA_dmem_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(1, 1'b0) xA_stall_reg (.in(case_1_stall), .out(xA_load_use_stall), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(1, 1'b0) xA_r1_re_reg (.in(dA_r1_re), .out(xA_r1_re), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0) xA_r2_re_reg (.in(dA_r2_re), .out(xA_r2_re), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));


   // mx, wx
   wire xA_r1_mB_bp = (xA_r1_sel == mB_rd_sel) && mB_rd_we && !mB_load_use_stall;
   wire xA_r1_mA_bp = (xA_r1_sel == mA_rd_sel) && mA_rd_we && !mA_load_use_stall;
   wire xA_r1_wB_bp = (xA_r1_sel == wB_rd_sel) && wB_rd_we && !wB_load_use_stall;
   wire xA_r1_wA_bp = (xA_r1_sel == wA_rd_sel) && wA_rd_we && !wA_load_use_stall;

   assign xA_r1_bp_out = xA_r1_mB_bp ? mB_alu_out :
                           xA_r1_mA_bp ? mA_alu_out :
                           xA_r1_wB_bp ? wB_dmem_mux_out :
                           xA_r1_wA_bp ? wA_dmem_mux_out :
                           xA_rs;

   wire xA_r2_mB_bp = (xA_r2_sel == mB_rd_sel) && mB_rd_we && !mB_load_use_stall;
   wire xA_r2_mA_bp = (xA_r2_sel == mA_rd_sel) && mA_rd_we && !mA_load_use_stall;
   wire xA_r2_wB_bp = (xA_r2_sel == wB_rd_sel) && wB_rd_we && !wB_load_use_stall;
   wire xA_r2_wA_bp = (xA_r2_sel == wA_rd_sel) && wA_rd_we && !wA_load_use_stall;

   assign xA_r2_bp_out = xA_r2_mB_bp ? mB_alu_out :
                           xA_r2_mA_bp ? mA_alu_out :
                           xA_r2_wB_bp ? wB_dmem_mux_out :
                           xA_r2_wA_bp ? wA_dmem_mux_out :
                           xA_rt;

   // ALU
   lc4_alu alu_A(
         .i_insn(xA_insn), //CHECK: might be x_pc_reg
         .i_pc(xA_pc),
         .i_r1data(xA_r1_bp_out),
         .i_r2data(xA_r2_bp_out),
         .o_result(xA_alu_out)
   );

   // NZP Bits
   nzp nzp_A(
      .nzp_we(xA_nzp_we),
      .data(xA_alu_out),
      .insn(xA_insn),
      .pc_plus_1_select(xA_pc_plus_1_select),
      .nzp_bits(xA_nzp_bits)
   );
   

// ************************************* MEMORY A ******************************************

   // Wires
   wire [15:0] mA_pc;
   wire [15:0] mA_pc_plus_1;
   wire [15:0] mA_insn;

   wire [15:0] mA_wm_bp_out;
   wire [15:0] mA_alu_out, mA_dmem_addr, mA_dmem_data, mA_dmem_out, mA_dmem_mux_out;
   
   wire [15:0] mA_rt;

   wire [2:0] mA_r2_sel, mA_rd_sel;

   wire mA_r1_re;
   wire mA_r2_re;
   wire mA_rd_we;
   wire mA_dmem_we;

   wire mA_pc_plus_1_select;
   wire mA_is_load;
   wire mA_nzp_we;

   wire mA_load_use_stall;


   // M.A phase registers
   Nbit_reg #(16, 16'h0000) mA_pc_reg (.in(xA_pc), .out(mA_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h8201) mA_pc_inc_reg (.in(xA_pc_plus_1), .out(mA_pc_plus_1), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) mA_insn_reg (.in(xA_insn), .out(mA_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(1, 1'b0) mA_pc_plus_1_select_reg (.in(xA_pc_plus_1_select), .out(mA_pc_plus_1_select), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0) mA_is_load_reg (.in(xA_is_load), .out(mA_is_load), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0) mA_nzp_we_reg (.in(xA_nzp_we), .out(mA_nzp_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0) mA_dmem_we_reg (.in(xA_dmem_we), .out(mA_dmem_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   
   Nbit_reg #(16, 16'b0) mA_alu_out_reg (.in(xA_alu_out), .out(mA_alu_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(3, 3'b0) mA_r2_sel_reg (.in(xA_r2_sel), .out(mA_r2_sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'b0) mA_rd_sel_reg (.in(xA_rd_sel), .out(mA_rd_sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0) mA_rd_we_reg (.in(xA_rd_we), .out(mA_rd_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));


   Nbit_reg #(1, 1'b0) mA_stall_reg (.in(xA_load_use_stall), .out(mA_load_use_stall), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(1, 1'b0) mA_r1_re_reg (.in(xA_r1_re), .out(mA_r1_re), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0) mA_r2_re_reg (.in(xA_r2_re), .out(mA_r2_re), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(16, 16'b0) mA_rt_reg (.in(xA_r2_bp_out), .out(mA_rt), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); 


   // wm bypass
   assign mA_wm_bp_out = (mA_dmem_we && wB_rd_sel == mA_r2_sel 
            && wB_rd_we && mA_r2_re) ? wB_dmem_mux_out:
            (mA_dmem_we && wA_rd_sel == mA_r2_sel 
            && wA_rd_we && mA_r2_re) ? wA_dmem_mux_out : mA_rt;
   

   // DATA MODULE
   assign mA_dmem_addr = (!mA_load_use_stall) && (mA_is_load | mA_dmem_we) ? mA_alu_out : 16'b0;

   assign o_dmem_addr = (!mA_load_use_stall) && (mA_is_load | mA_dmem_we) ? mA_dmem_addr :
                        !(mB_load_use_stall || mB_ss_stall) && (mB_is_load | mB_dmem_we) ? mB_dmem_addr :
                        16'b0;
   
   assign o_dmem_we = mA_dmem_we | mB_dmem_we;

   assign o_dmem_towrite = (mA_dmem_we) ? mA_wm_bp_out : mB_mm_bp_out;

   assign mA_dmem_out = mA_is_load ? i_cur_dmem_data : 16'b0;


// ************************************* WRITEBACK A ******************************************

   // Wires
   wire [15:0] wA_pc;
   wire [15:0] wA_pc_plus_1;
   wire [15:0] wA_insn;

   wire [15:0] wA_alu_out;
   wire [15:0] wA_dmem_out;
   wire [15:0] wA_dmem_mux_out;

   wire wA_nzp_we;
   wire wA_pc_plus_1_select;
   wire wA_is_load;
   wire wA_rd_we;

   wire [2:0] wA_rd_sel;
   wire [2:0] wA_new_nzp_bits;

   wire wA_dmem_we;
   wire [15:0] wA_dmem_addr;
   wire [15:0] wA_dmem_towrite;

   wire wA_load_use_stall;


   Nbit_reg #(16, 16'h0000) wA_pc_reg (.in(mA_pc), .out(wA_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h8201) wA_pc_inc_reg (.in(mA_pc_plus_1), .out(wA_pc_plus_1), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) wA_insn_reg (.in(mA_insn), .out(wA_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   
   Nbit_reg #(16, 16'b0) wA_alu_out_reg (.in(mA_alu_out), .out(wA_alu_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) wA_dmem_out_reg (.in(mA_dmem_out), .out(wA_dmem_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(1, 1'b0) wA_nzp_we_reg (.in(mA_nzp_we), .out(wA_nzp_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0) wA_pc_plus_1_select_reg (.in(mA_pc_plus_1_select), .out(wA_pc_plus_1_select), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0) wA_is_load_reg (.in(mA_is_load), .out(wA_is_load), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0) wA_rd_we_reg (.in(mA_rd_we), .out(wA_rd_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(3, 3'b0) wA_rd_sel_reg (.in(mA_rd_sel), .out(wA_rd_sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(1, 1'b0) wA_dmem_we_reg (.in(mA_dmem_we), .out(wA_dmem_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) wA_dmem_addr_reg (.in(mA_dmem_addr), .out(wA_dmem_addr), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) wA_dmem_towrite_reg (.in(mA_wm_bp_out), .out(wA_dmem_towrite), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(1, 1'b0) wA_stall_reg (.in(mA_load_use_stall), .out(wA_load_use_stall), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));


   // rd write data
   assign wA_dmem_mux_out = (wA_is_load) ? wA_dmem_out:
                        (wA_pc_plus_1_select) ? wA_pc_plus_1:
                        wA_alu_out;

   // Update NZP
   assign wA_new_nzp_bits = (wA_dmem_mux_out[15] == 1) ? 4 : 
      (wA_dmem_mux_out == 0) ? 2 : 
      (wA_dmem_mux_out > 0) ? 1 : 0;


   // ************************** Test Wires A **************************

   assign test_stall_A = (wA_pc == 16'b0) ? 2'd2 : 
                           (wA_load_use_stall) ? 2'd3 :
                           2'd0;

   assign test_cur_pc_A = wA_pc;
   assign test_cur_insn_A = wA_insn;

   assign test_regfile_we_A = wA_rd_we;
   assign test_regfile_wsel_A = wA_rd_sel;
   assign test_regfile_data_A = wA_dmem_mux_out;

   assign test_nzp_we_A = wA_nzp_we;
   assign test_nzp_new_bits_A = wA_new_nzp_bits;
   
   assign test_dmem_we_A = wA_dmem_we;
   assign test_dmem_addr_A = wA_dmem_addr;
   assign test_dmem_data_A = wA_dmem_we ? wA_dmem_towrite : wA_dmem_out;


// ****************************************** DECODE B ***************************************************


   // PC/insn wires
   wire [15:0] dB_pc;
   wire [15:0] dB_pc_plus_1;
   wire [15:0] dB_insn;

   // Decoder wires
   wire [2:0] dB_r1_sel, dB_r2_sel, dB_rd_sel;
   wire dB_r1_re, dB_r2_re, dB_rd_we, dB_nzp_we, dB_pc_plus_1_select;
   wire dB_is_load, dB_is_branch, dB_is_control_insn, dB_dmem_we;

   // Reg file output wires
   wire [15:0] dB_rs, dB_rt;

   // Stall signals;
   wire dB_ss_stall;
   wire dB_load_use_stall;


   // Post stall check wires
   wire dB_psc_is_load;
   wire dB_psc_is_branch;
   wire dB_psc_is_control_insn;
   wire dB_psc_dmem_we;
   wire dB_psc_rd_we;

   // D.B phase registers
   Nbit_reg #(16, 16'h0000) dB_pc_reg (.in(f_psc_pc_plus_1), .out(dB_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h8201) dB_pc_inc_reg (.in(f_psc_pc_plus_2), .out(dB_pc_plus_1), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) dB_insn_reg (.in(fB_psc_insn), .out(dB_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   // Decoder
   lc4_decoder dB_decode(
      .insn(dB_insn),                        // instruction
      .r1sel(dB_r1_sel),                     // rs
      .r1re(dB_r1_re),                       // does this instruction read from rs?
      .r2sel(dB_r2_sel),                     // rt
      .r2re(dB_r2_re),                       // does this instruction read from rt?
      .wsel(dB_rd_sel),                      // rd
      .regfile_we(dB_rd_we),                 // does this instruction write to rd?
      .nzp_we(dB_nzp_we),                    // does this instruction write the NZP bits?
      .select_pc_plus_one(dB_pc_plus_1_select), // write PC+1 to the regfile?
      .is_load(dB_is_load),                  // is this a load instruction?
      .is_store(dB_dmem_we),                 // is this a store instruction?
      .is_branch(dB_is_branch),              // is this a branch instruction?
      .is_control_insn(dB_is_control_insn)   // is this a control instruction (JSR, JSRR, RTI, JMPR, JMP, TRAP)?
   );

   // Stall check
   assign dB_ss_stall = case_1_stall | case_3_stall | case_4_stall;
   assign dB_load_use_stall = ~dB_ss_stall & case_2_stall;
   assign dB_psc_is_load = (dB_ss_stall | dB_load_use_stall) ? 1'b0 : dB_is_load;
   assign dB_psc_is_branch = (dB_ss_stall | dB_load_use_stall) ? 1'b0 : dB_is_branch;
   assign dB_psc_is_control_insn = (dB_ss_stall | dB_load_use_stall) ? 1'b0 : dB_is_control_insn;
   assign dB_psc_dmem_we = (dB_ss_stall | dB_load_use_stall) ? 1'b0 : dB_dmem_we;
   assign dB_psc_rd_we = (dB_ss_stall | dB_load_use_stall) ? 1'b0 : dB_rd_we;

// ************************************* EXECUTE B ******************************************

   // Wires
   wire [15:0] xB_pc;
   wire [15:0] xB_pc_plus_1;
   wire [15:0] xB_insn;

   wire [15:0] xB_rs, xB_rt;

   wire xB_dmem_we;

   wire [2:0] xB_r1_sel, xB_r2_sel, xB_rd_sel;
   wire xB_rd_we, xB_nzp_we, xB_pc_plus_1_select; 
   wire xB_is_load, xB_is_branch, xB_is_control_insn;

   wire xB_r1_re;
   wire xB_r2_re;

   wire [15:0] xB_alu_out;

   // R1 mux for WX and MX bypassing
   wire [15:0] xB_r1_bp_out, xB_r2_bp_out;

   // NZP wires
   wire xB_nzp_out;
   wire [2:0] xB_nzp_bits;
   wire [2:0] xB_nzp_reg_out;

   wire xB_ss_stall;
   wire xB_load_use_stall;


   // X.B Phase Registers
   Nbit_reg #(16, 16'h0000) xB_pc_reg (.in(dB_pc), .out(xB_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h8201) xB_pc_plus_1_reg (.in(dB_pc_plus_1), .out(xB_pc_plus_1), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) xB_insn_reg (.in(dB_insn), .out(xB_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(16, 16'b0) xB_rs_reg (.in(dB_rs), .out(xB_rs), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) xB_rt_reg (.in(dB_rt), .out(xB_rt), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); 

   Nbit_reg #(3, 3'b0) xB_r1_sel_reg (.in(dB_r1_sel), .out(xB_r1_sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'b0) xB_r2_sel_reg (.in(dB_r2_sel), .out(xB_r2_sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'b0) xB_rd_sel_reg (.in(dB_rd_sel), .out(xB_rd_sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0) xB_rd_we_reg (.in(dB_psc_rd_we), .out(xB_rd_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(1, 1'b0) xB_pc_plus_1_select_reg (.in(dB_pc_plus_1_select), .out(xB_pc_plus_1_select), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0) xB_is_load_reg (.in(dB_psc_is_load), .out(xB_is_load), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0) xB_is_branch_reg (.in(dB_psc_is_branch), .out(xB_is_branch), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0) xB_is_control_reg (.in(dB_psc_is_control_insn), .out(xB_is_control_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(1, 1'b0) xB_nzp_we_reg (.in(dB_nzp_we), .out(xB_nzp_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(1, 1'b0) xB_dmem_we_reg (.in(dB_psc_dmem_we), .out(xB_dmem_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(1, 1'b0) xB_ltu_stall_reg (.in(dB_load_use_stall), .out(xB_load_use_stall), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0) xB_ss_stall_reg (.in(dB_ss_stall), .out(xB_ss_stall), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(1, 1'b0) xB_r1_re_reg (.in(dB_r1_re), .out(xB_r1_re), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0) xB_r2_re_reg (.in(dB_r2_re), .out(xB_r2_re), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   // mx, wx
   // assign xB_r1_bp_out = ((xB_r1_sel == mB_rd_sel) && mB_rd_we && !mB_load_use_stall) ? mB_alu_out :
   //                      ((xB_r1_sel == wB_rd_sel) && wB_rd_we && !wB_load_use_stall) ? wB_dmem_mux_out :
   //                      xB_rs;

   // assign xB_r2_bp_out = ((xB_r2_sel == mB_rd_sel) && mB_rd_we && !mB_load_use_stall) ? mB_alu_out :
   //                      ((xB_r2_sel == wB_rd_sel) && wB_rd_we && !wB_load_use_stall) ? wB_dmem_mux_out :
   //                      xB_rt;

   wire xB_r1_mB_bp = (xB_r1_sel == mB_rd_sel) && mB_rd_we && !mB_load_use_stall;
   wire xB_r1_mA_bp = (xB_r1_sel == mA_rd_sel) && mA_rd_we && !mA_load_use_stall;
   wire xB_r1_wB_bp = (xB_r1_sel == wB_rd_sel) && wB_rd_we && !wB_load_use_stall;
   wire xB_r1_wA_bp = (xB_r1_sel == wA_rd_sel) && wA_rd_we && !wA_load_use_stall;

   assign xB_r1_bp_out = xB_r1_mB_bp ? mB_alu_out :
                           xB_r1_mA_bp ? mA_alu_out :
                           xB_r1_wB_bp ? wB_dmem_mux_out :
                           xB_r1_wA_bp ? wA_dmem_mux_out :
                           xB_rs;

   wire xB_r2_mB_bp = (xB_r2_sel == mB_rd_sel) && mB_rd_we && !mB_load_use_stall;
   wire xB_r2_mA_bp = (xB_r2_sel == mA_rd_sel) && mA_rd_we && !mA_load_use_stall;
   wire xB_r2_wB_bp = (xB_r2_sel == wB_rd_sel) && wB_rd_we && !wB_load_use_stall;
   wire xB_r2_wA_bp = (xB_r2_sel == wA_rd_sel) && wA_rd_we && !wA_load_use_stall;

   assign xB_r2_bp_out = xB_r2_mB_bp ? mB_alu_out :
                           xB_r2_mA_bp ? mA_alu_out :
                           xB_r2_wB_bp ? wB_dmem_mux_out :
                           xB_r2_wA_bp ? wA_dmem_mux_out :
                           xB_rt;


   //ALU
   lc4_alu alu_B(
         .i_insn(xB_insn), 
         .i_pc(xB_pc),
         .i_r1data(xB_r1_bp_out),
         .i_r2data(xB_r2_bp_out),
         .o_result(xB_alu_out)
   );

   // NZP Bits
   nzp nzp_B(
      .nzp_we(xB_nzp_we),
      .data(xB_alu_out),
      .insn(xB_insn),
      .pc_plus_1_select(xB_pc_plus_1_select),
      .nzp_bits(xB_nzp_bits)
   );



// ************************************* MEMORY B ******************************************

   // Wires
   wire [15:0] mB_pc;
   wire [15:0] mB_pc_plus_1;
   wire [15:0] mB_insn;

   wire [15:0] mB_wm_bp_out;
   wire [15:0] mB_mm_bp_out;
   wire [15:0] mB_alu_out, mB_dmem_addr, mB_dmem_data, mB_dmem_out, mB_dmem_mux_out;
   
   wire [15:0] mB_rt;

   wire [2:0] mB_r2_sel, mB_rd_sel;

   wire mB_r1_re;
   wire mB_r2_re;
   wire mB_rd_we;
   wire mB_dmem_we;

   wire mB_pc_plus_1_select;
   wire mB_is_load;
   wire mB_nzp_we;

   wire mB_load_use_stall;
   wire mB_ss_stall;   



   // M.A phase registers
   Nbit_reg #(16, 16'h0000) mB_pc_reg (.in(xB_pc), .out(mB_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h8201) mB_pc_inc_reg (.in(xB_pc_plus_1), .out(mB_pc_plus_1), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) mB_insn_reg (.in(xB_insn), .out(mB_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(1, 1'b0) mB_pc_plus_1_select_reg (.in(xB_pc_plus_1_select), .out(mB_pc_plus_1_select), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0) mB_is_load_reg (.in(xB_is_load), .out(mB_is_load), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   
   Nbit_reg #(3, 3'b0) mB_r2_sel_reg (.in(xB_r2_sel), .out(mB_r2_sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'b0) mB_rd_sel_reg (.in(xB_rd_sel), .out(mB_rd_sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0) mB_rd_we_reg (.in(xB_rd_we), .out(mB_rd_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(1, 1'b0) mB_nzp_we_reg (.in(xB_nzp_we), .out(mB_nzp_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(1, 1'b0) mB_dmem_we_reg (.in(xB_dmem_we), .out(mB_dmem_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(16, 16'b0) mB_alu_out_reg (.in(xB_alu_out), .out(mB_alu_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(1, 1'b0) mB_ltu_stall_reg (.in(xB_load_use_stall), .out(mB_load_use_stall), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0) mB_ss_stall_reg (.in(xB_ss_stall), .out(mB_ss_stall), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(1, 1'b0) mB_r1_re_reg (.in(xB_r1_re), .out(mB_r1_re), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0) mB_r2_re_reg (.in(xB_r2_re), .out(mB_r2_re), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(16, 16'b0) mB_rt_reg (.in(xB_r2_bp_out), .out(mB_rt), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); 

   // wm bypass
   assign mB_wm_bp_out =   (mB_dmem_we && wB_rd_sel == mB_r2_sel 
                           && wB_rd_we && mB_r2_re) ? wB_dmem_mux_out : 
                           (mB_dmem_we && wA_rd_sel == mB_r2_sel
                           && wA_rd_we && mB_r2_re) ? wA_dmem_mux_out :
                           mB_rt;

   // mm bypass
   assign mB_mm_bp_out = (mB_dmem_we && (mA_rd_sel == mB_r2_sel)
            && mA_rd_we && mB_r2_re) ? mA_alu_out : mB_wm_bp_out;

   // DATA MODULE
   assign mB_dmem_addr = !(mB_load_use_stall || mB_ss_stall) && (mB_is_load | mB_dmem_we) ? mB_alu_out : 16'b0;

   assign mB_dmem_out = mB_is_load ? i_cur_dmem_data : 16'b0;


// ************************************* WRITEBACK B ******************************************

   // Wires
   wire [15:0] wB_pc;
   wire [15:0] wB_pc_plus_1;
   wire [15:0] wB_insn;

   wire [15:0] wB_alu_out;
   wire [15:0] wB_dmem_out;
   wire [15:0] wB_dmem_mux_out;

   wire wB_nzp_we;
   wire wB_pc_plus_1_select;
   wire wB_is_load;
   wire wB_rd_we;

   wire [2:0] wB_rd_sel;
   wire [2:0] wB_new_nzp_bits;

   wire wB_dmem_we;
   wire [15:0] wB_dmem_addr;
   wire [15:0] wB_dmem_towrite;

   wire wB_load_use_stall;
   wire wB_ss_stall;   



   Nbit_reg #(16, 16'h0000) wB_pc_reg (.in(mB_pc), .out(wB_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h8201) wB_pc_inc_reg (.in(mB_pc_plus_1), .out(wB_pc_plus_1), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) wB_insn_reg (.in(mB_insn), .out(wB_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   
   Nbit_reg #(16, 16'b0) wB_alu_out_reg (.in(mB_alu_out), .out(wB_alu_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) wB_dmem_out_reg (.in(mB_dmem_out), .out(wB_dmem_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(1, 1'b0) wB_nzp_we_reg (.in(mB_nzp_we), .out(wB_nzp_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0) wB_pc_plus_1_select_reg (.in(mB_pc_plus_1_select), .out(wB_pc_plus_1_select), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0) wB_is_load_reg (.in(mB_is_load), .out(wB_is_load), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0) wB_rd_we_reg (.in(mB_rd_we), .out(wB_rd_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(3, 3'b0) wB_rd_sel_reg (.in(mB_rd_sel), .out(wB_rd_sel), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(1, 1'b0) wB_dmem_we_reg (.in(mB_dmem_we), .out(wB_dmem_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) wB_dmem_addr_reg (.in(mB_dmem_addr), .out(wB_dmem_addr), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'b0) wB_dmem_towrite_reg (.in(mB_mm_bp_out), .out(wB_dmem_towrite), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(1, 1'b0) wB_ss_stall_reg (.in(mB_ss_stall), .out(wB_ss_stall), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'b0) wB_ltu_stall_reg (.in(mB_load_use_stall), .out(wB_load_use_stall), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));


   // rd write data
   assign wB_dmem_mux_out = (wB_is_load) ? wB_dmem_out:
                        (wB_pc_plus_1_select) ? wB_pc_plus_1:
                        wB_alu_out;

   // Update NZP
   assign wB_new_nzp_bits = (wB_dmem_mux_out[15] == 1) ? 4 : 
      (wB_dmem_mux_out == 0) ? 2 : 
      (wB_dmem_mux_out > 0) ? 1 : 0;


   // ************************** Test Wires B **************************

   assign test_stall_B = (wB_pc == 16'b0) ? 2'd2 :
                           (wB_load_use_stall) ? 2'd3 :
                           (wB_ss_stall) ? 2'd1 :
                           2'd0;

   assign test_cur_pc_B = wB_pc;
   assign test_cur_insn_B = wB_insn;

   assign test_regfile_we_B = wB_rd_we;
   assign test_regfile_wsel_B = wB_rd_sel;
   assign test_regfile_data_B = wB_dmem_mux_out;

   assign test_nzp_we_B = wB_nzp_we;
   assign test_nzp_new_bits_B = wB_new_nzp_bits;
   
   assign test_dmem_we_B = wB_dmem_we;
   assign test_dmem_addr_B = wB_dmem_addr;
   assign test_dmem_data_B = wB_dmem_we ? wB_dmem_towrite : wB_dmem_out;






   /* Add $display(...) calls in the always block below to
    * print out debug information at the end of every cycle.
    *
    * You may also use if statements inside the always block
    * to conditionally print out information.
    */
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
      // run it for that many nanoseconds, then set
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
endmodule

module nzp(
   input wire nzp_we,
   input wire [15:0]  data,
   input wire [15:0] insn,
   input wire pc_plus_1_select,
   output wire [2:0] nzp_bits);

   assign nzp_bits = (pc_plus_1_select) ? 1 :
      (data[15] == 1) ? 4 : 
      (data == 0) ? 2 : 
      (data > 0) ? 1 : 
      0;

endmodule