`timescale 1ns / 1ps
`default_nettype none

// set this to 1 to exit after the first failure
`define EXIT_AFTER_FIRST_ERROR 0

// change this to adjust how many errors are printed out
`define MAX_ERRORS_TO_DISPLAY 7

// set this to 1 to create a waveform file for easier debugging
`define GENERATE_VCD 0


`define EOF 32'hFFFF_FFFF
`define NEWLINE 10
`define NULL 0

// NB: .set_testcase.v is auto-generated by vivado.mk
`include ".set_testcase.v"

module test_processor;
   `include "print_points.v"
   `include "include/lc4_prettyprint_errors.v"
   
   integer     input_file, output_file, errors, tests;
   integer     insns; 
   integer     num_cycles;
   integer     consecutive_stalls;

   // Inputs
   reg clk;
   reg rst;
   wire [15:0] cur_insn;
   wire [15:0] cur_dmem_data;

   // Outputs
   wire [15:0] cur_pc;
   wire [15:0] dmem_addr;
   wire [15:0] dmem_towrite;
   wire        dmem_we;

   wire [15:0] test_pc;           // Testbench: program counter
   wire [15:0] test_insn;         // Testbench: instruction bits
   wire [1:0]  test_stall;        // Testbench: is this a stall cycle?
   wire        test_regfile_we;   // Testbench: register file write enable
   wire [2:0]  test_regfile_reg;  // Testbench: which register to write in the register file 
   wire [15:0] test_regfile_in;   // Testbench: value to write into the register file
   wire        test_nzp_we;       // Testbench: NZP condition codes write enable
   wire [2:0]  test_nzp_new_bits; // Testbench: value to write to NZP bits
   wire        test_dmem_we;      // Testbench: data memory write enable
   wire [15:0] test_dmem_addr;    // Testbench: address to write to memory
   wire [15:0] test_dmem_data;    // Testbench: value to write to memory

   reg  [15:0] verify_pc;
   reg  [15:0] verify_insn;
   reg  [1:0]  verify_stall; 
   reg         verify_regfile_we;
   reg  [2:0]  verify_regfile_reg;
   reg  [15:0] verify_regfile_in;
   reg         verify_nzp_we;
   reg  [2:0]  verify_nzp_new_bits;
   reg         verify_dmem_we;
   reg  [15:0] verify_dmem_addr;
   reg  [15:0] verify_dmem_data;
   reg [15:0]  file_status;
   
   wire [15:0] vout_dummy;  // video out
   
   always #5 clk <= ~clk;
   
   // Produce gwe and other we signals using same modules as lc4_system
   wire        i1re, i2re, dre, gwe;
   lc4_we_gen we_gen(.clk(clk),
		     .i1re(i1re),
		     .i2re(i2re),
		     .dre(dre),
		     .gwe(gwe));
  
   
   // Data and video memory block 
   lc4_memory memory (.idclk(clk),
		      .i1re(i1re),
		      .i2re(i2re),
		      .dre(dre),
		      .gwe(gwe),
		      .rst(rst),
                      .i1addr(cur_pc),
		      .i2addr(16'd0),      // Not used for scalar processors
                      .i1out(cur_insn),
                      .daddr(dmem_addr),
		      .din(dmem_towrite),
                      .dout(cur_dmem_data),
                      .dwe(dmem_we),
                      .vclk(1'b0),
                      .vaddr(16'h0000),
                      .vout(vout_dummy));
   
   
   // Instantiate the Unit Under Test (UUT)
   lc4_processor proc_inst (.clk(clk), 
                            .rst(rst),
                            .gwe(gwe),
                            .o_cur_pc(cur_pc), 
                            .i_cur_insn(cur_insn), 
                            .o_dmem_addr(dmem_addr), 
                            .o_dmem_towrite(dmem_towrite), 
                            .i_cur_dmem_data(cur_dmem_data), 
                            .o_dmem_we(dmem_we),
                            .test_stall(test_stall),
                            .test_cur_pc(test_pc),
                            .test_cur_insn(test_insn),
                            .test_regfile_we(test_regfile_we),
                            .test_regfile_wsel(test_regfile_reg),
                            .test_regfile_data(test_regfile_in),
                            .test_nzp_we(test_nzp_we),
                            .test_nzp_new_bits(test_nzp_new_bits),
                            .test_dmem_we(test_dmem_we),
                            .test_dmem_addr(test_dmem_addr),
                            .test_dmem_data(test_dmem_data),
                            .switch_data(8'd0)
                            );
   
   initial begin
      if (`GENERATE_VCD) begin
         $dumpfile("pipeline.vcd");
         $dumpvars;
      end
      
      // Initialize Inputs
      clk = 0;
      rst = 1;
      insns = 0;
      errors = 0;
      tests = 0; 
      num_cycles = 0;
      file_status = 10;
      consecutive_stalls = 0;
      
      // open the test inputs
      input_file = $fopen(`INPUT_FILE, "r");
      if (input_file == `NULL) begin
         $display("Error opening file: %s", `INPUT_FILE);
         $finish;
      end

      // open the output file
// `ifdef OUTPUT_FILE
//       output_file = $fopen(`OUTPUT_FILE, "w");
//       if (output_file == `NULL) begin
//          $display("Error opening file: %s", `OUTPUT_FILE);
//          $finish;
//       end
// `endif


      #80; 
      // Wait for global reset to finish
      rst = 0;
      #32;
  
      while (11 == $fscanf(input_file, "%h %b %h %h %h %h %h %h %h %h %h", 
                           verify_pc,
                           verify_insn,
                           verify_stall,
                           verify_regfile_we,
                           verify_regfile_reg,
                           verify_regfile_in,
                           verify_nzp_we,
                           verify_nzp_new_bits,
                           verify_dmem_we,
                           verify_dmem_addr,
                           verify_dmem_data)) begin

         if (num_cycles % 10000 == 0) begin
            $display("Cycle number: %d", num_cycles);
         end

         if (verify_stall == 2'b00) begin
            insns = insns + 1; 
         end
            
         if (output_file) begin
            $fdisplay(output_file, "%h %b %h %h %h %h %h %h %h %h %h",
                      verify_pc,
                      verify_insn,
                      verify_stall,
                      verify_regfile_we,
                      verify_regfile_reg,
                      verify_regfile_in,
                      verify_nzp_we,
                      verify_nzp_new_bits,
                      verify_dmem_we,
                      verify_dmem_addr,
                      verify_dmem_data);
         end

         // run the cycle, then verify outputs
         num_cycles = num_cycles + 1;
	 #40;

         tests = tests + 1;

         if (errors <= `MAX_ERRORS_TO_DISPLAY && num_cycles >= 1110) begin 
               $write("%d:", num_cycles);
               pinstr(test_insn);
               $display("");
            end
         
       // stall
         if (verify_stall !== test_stall) begin
            if (errors <= `MAX_ERRORS_TO_DISPLAY) begin 
               $display( "Error at cycle %d: stall should be %h (but was %h)", 
                         num_cycles, verify_stall, test_stall);
            end
            errors = errors + 1;
         end 

         // count consecutive stalls
         if (test_stall !== 3'b000) begin
            if (consecutive_stalls >= 5) begin
               $display("Error at cycle %d: your pipeline has stalled for more than 5 cycles in a row, which should never happen. This might indicate your pipeline will be stuck stalling forever.", num_cycles);
               // exit testbench if pipeline gets stuck
               printPoints(tests, 0); 
               $finish;
            end
            consecutive_stalls = consecutive_stalls + 1;
         end else begin
            consecutive_stalls = 0;
         end

         // in stall cycles, ensure no writes are happening
         // NB: not ready yet, sometimes in the reference trace write-enables are set during stall cycles...
         // if (verify_stall !== 2'b00 && num_cycles >= 1114) begin 
         //    if (verify_regfile_we !== test_regfile_we) begin
         //       if (errors <= `MAX_ERRORS_TO_DISPLAY) begin 
         //          $display( "Error at cycle %d: regfile_we should be %h (but was %h)", 
         //                    num_cycles, verify_regfile_we, test_regfile_we);
         //       end
         //       errors = errors + 1;
         //    end
         //    if (verify_nzp_we !== test_nzp_we) begin
         //       if (errors <= `MAX_ERRORS_TO_DISPLAY) begin 
         //          $display( "Error at cycle %d: nzp_we should be %h (but was %h)", 
         //                    num_cycles, verify_nzp_we, test_nzp_we);
         //       end
         //       errors = errors + 1;
         //    end
         //    if (verify_dmem_we !== test_dmem_we) begin
         //       if (errors <= `MAX_ERRORS_TO_DISPLAY) begin 
         //          $display( "Error at cycle %d: dmem_we should be %h (but was %h)", 
         //                    num_cycles, verify_dmem_we, test_dmem_we);
         //       end
         //       errors = errors + 1;
         //    end            
         // end

         if (verify_stall === 2'b00) begin // if it's a non-stall cycle, verify other test_* signals

            tests = tests + 10; 
            
            // pc
            if (verify_pc !== test_pc) begin
               if (errors <= `MAX_ERRORS_TO_DISPLAY) begin 
                  $display( "Error at cycle %d: pc should be %h (but was %h)", 
                            num_cycles, verify_pc, test_pc);
               end
               errors = errors + 1;
            end
            
            // insn
            if (verify_insn !== test_insn) begin
               if (errors <= `MAX_ERRORS_TO_DISPLAY) begin 
                  $write("Error at cycle %d: insn should be %h (", num_cycles, verify_insn);
                  pinstr(verify_insn);
                  $write(") but was %h (", test_insn);
                  pinstr(test_insn);
                  $display(")");
               end
               errors = errors + 1;
            end

            // regfile_we
            if (verify_regfile_we !== test_regfile_we) begin
               if (errors <= `MAX_ERRORS_TO_DISPLAY) begin 
                  $display( "Error at cycle %d: regfile_we should be %h (but was %h)", 
                            num_cycles, verify_regfile_we, test_regfile_we);
               end
               errors = errors + 1;
            end
            
            // regfile_reg
            if (verify_regfile_we && verify_regfile_reg !== test_regfile_reg) begin
               if (errors <= `MAX_ERRORS_TO_DISPLAY) begin 
                  $display( "Error at cycle %d: regfile_reg should be %h (but was %h)", 
                            num_cycles, verify_regfile_reg, test_regfile_reg);
               end
               errors = errors + 1;
            end
            
            // regfile_in
            if (verify_regfile_we && verify_regfile_in !== test_regfile_in) begin
               if (errors <= `MAX_ERRORS_TO_DISPLAY) begin 
                  $display( "Error at cycle %d: regfile_in should be %h (but was %h)", 
                            num_cycles, verify_regfile_in, test_regfile_in);
               end
               errors = errors + 1;
            end
            
            // verify_nzp_we
            if (verify_nzp_we !== test_nzp_we) begin
               if (errors <= `MAX_ERRORS_TO_DISPLAY) begin 
                  $display( "Error at cycle %d: nzp_we should be %h (but was %h)", 
                            num_cycles, verify_nzp_we, test_nzp_we);
               end
               errors = errors + 1;
            end
            
            // verify_nzp_new_bits
            if (verify_nzp_we && verify_nzp_new_bits !== test_nzp_new_bits) begin
               if (errors <= `MAX_ERRORS_TO_DISPLAY) begin 
                  $display( "Error at cycle %d: nzp_new_bits should be %h (but was %h)", 
                            num_cycles, verify_nzp_new_bits, test_nzp_new_bits);
               end
               errors = errors + 1;
            end
            
            // verify_dmem_we
            if (verify_dmem_we !== test_dmem_we) begin
               if (errors <= `MAX_ERRORS_TO_DISPLAY) begin 
                  $display( "Error at cycle %d: dmem_we should be %h (but was %h)", 
                            num_cycles, verify_dmem_we, test_dmem_we);
               end
               errors = errors + 1;
            end
            
            // dmem_addr
            if (verify_dmem_addr !== test_dmem_addr) begin
               if (errors <= `MAX_ERRORS_TO_DISPLAY) begin 
                  $display( "Error at cycle %d: dmem_addr should be %h (but was %h)", 
                            num_cycles, verify_dmem_addr, test_dmem_addr);
               end
               errors = errors + 1;
            end
            
            // dmem_data
            if (verify_dmem_data !== test_dmem_data) begin
               if (errors <= `MAX_ERRORS_TO_DISPLAY) begin 
                  $display( "Error at cycle %d: dmem_data should be %h (but was %h)", 
                            num_cycles, verify_dmem_data, test_dmem_data);
               end
               errors = errors + 1;
            end
          end // non-stall cycle

         //if (`EXIT_AFTER_FIRST_ERROR &&  errors > 0) begin
         // if (errors > 6) begin
         //    $display("Exiting after first error..."); 
         //    $finish;
         // end 
                  
      end // while ($fscanf(input_file, ...))
      if (errors > `MAX_ERRORS_TO_DISPLAY) begin
         $display("Additional %d errors NOT printed.", errors - `MAX_ERRORS_TO_DISPLAY);
      end
         
      if (input_file) $fclose(input_file); 
      if (output_file) $fclose(output_file);
      
      $display("Simulation finished: %d test cases %d errors [%s]", tests, errors, `INPUT_FILE);
      printPoints(tests, tests-errors); 
      
      
      $display("  Instructions:         %d", insns);
      $display("  Total Cycles:         %d", num_cycles);
      $display("  CPI x 1000: %d", (1000 * num_cycles) / insns);
      $display("  IPC x 1000: %d", (1000 * insns) / num_cycles);
            
      $finish;
   end // initial begin
   
endmodule
