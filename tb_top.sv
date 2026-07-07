`include "mem_defs.svh"
`include "mem_intf.sv"
`include "memory.sv"
`include "mem_tx.sv"
`include "mem_common.sv"
`include "mem_gen.sv"
`include "mem_bfm.sv"
`include "mem_mon.sv"
`include "mem_cov.sv"
`include "mem_sbd.sv"
`include "mem_agent.sv"
`include "mem_env.sv"

module tb_top;

  logic      clk;
  logic      rst;
  mem_intf   pif(clk, rst);
  mem_env    env;
  mem_common mem_common_i;

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  task reset_inputs();
    pif.addr_i  = '0;
    pif.wr_rd_i = '0;
    pif.wdata_i = '0;
    pif.valid_i = '0;
  endtask

  memory dut (
    .clk_i   (pif.clk_i),
    .rst_i   (pif.rst_i),
    .wr_rd_i (pif.wr_rd_i),
    .wdata_i (pif.wdata_i),
    .rdata_o (pif.rdata_o),
    .ready_o (pif.ready_o),
    .addr_i  (pif.addr_i),
    .valid_i (pif.valid_i)
  );

  property no_x_when_valid;
    @(posedge clk) disable iff (rst)
      pif.valid_i |-> !$isunknown({pif.addr_i, pif.wr_rd_i, pif.wdata_i});
  endproperty

  property ready_after_reset;
    @(posedge clk) !rst |-> pif.ready_o;
  endproperty

  assert property (no_x_when_valid)
    else $error("X/Z detected on active transaction inputs");

  assert property (ready_after_reset)
    else $error("ready_o should be high when not in reset");

  initial begin
    mem_common::num_agents = 1;
    mem_common_i           = new();
    mem_common::vif        = pif;

    rst = 1'b1;
    reset_inputs();

    repeat (3) @(posedge clk);
    rst = 1'b0;

    env = new();
    env.run();

    if (mem_common::num_mismatches > 0)
      $display("### TEST FAILED ###");
    else
      $display("### TEST PASSED ###");

    #20;
    $finish;
  end

endmodule
