`timescale 1ns/1ps

`define DEPTH      1024
`define ADDR_WIDTH $clog2(`DEPTH)
`define WIDTH      16

//============================================================
// Interface
//============================================================
interface mem_intf(input logic clk_i, rst_i);

  logic [`ADDR_WIDTH-1:0] addr_i;
  logic                   wr_rd_i;   // 1 = write, 0 = read
  logic [`WIDTH-1:0]      wdata_i;
  logic [`WIDTH-1:0]      rdata_o;
  logic                   valid_i;
  logic                   ready_o;

  // Driver clocking block
  clocking bfm_cb @(posedge clk_i);
    output addr_i, wdata_i, wr_rd_i, valid_i;
    input  rdata_o, ready_o;
  endclocking

  // Monitor clocking block
  clocking mon_cb @(posedge clk_i);
    input addr_i, wdata_i, wr_rd_i, valid_i, rdata_o, ready_o;
  endclocking

endinterface


//============================================================
// DUT : synchronous write, synchronous read
//============================================================
module memory (
  input  logic                    clk_i,
  input  logic                    rst_i,
  input  logic                    wr_rd_i,
  input  logic [`WIDTH-1:0]       wdata_i,
  output logic [`WIDTH-1:0]       rdata_o,
  output logic                    ready_o,
  input  logic [`ADDR_WIDTH-1:0]  addr_i,
  input  logic                    valid_i
);

  logic [`WIDTH-1:0] mem [0:`DEPTH-1];
  integer idx;

  assign ready_o = ~rst_i;

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      rdata_o <= '0;
      for (idx = 0; idx < `DEPTH; idx++) begin
        mem[idx] <= '0;
      end
    end
    else if (valid_i) begin
      if (wr_rd_i)
        mem[addr_i] <= wdata_i;
      else
        rdata_o <= mem[addr_i];
    end
  end

endmodule


//============================================================
// Transaction
//============================================================
class mem_tx;

  rand bit [`ADDR_WIDTH-1:0] addr;
  rand bit [`WIDTH-1:0]      data;
  rand bit                   wr_rd;

  function void print(string name = "mem_tx");
    $display("[%0t] %s : addr=0x%0h data=0x%0h wr_rd=%0d",
             $time, name, addr, data, wr_rd);
  endfunction

endclass


//============================================================
// Common Resources
//============================================================
class mem_common;

  static virtual mem_intf vif;

  static mailbox #(mem_tx) gen2bfmDA[];
  static mailbox #(mem_tx) mon2ref = new();
  static mailbox #(mem_tx) mon2cov = new();

  static semaphore smp = new(1);

  static int num_agents     = 1;
  static int num_matches    = 0;
  static int num_mismatches = 0;

  function new();
    gen2bfmDA = new[num_agents];
    foreach (gen2bfmDA[i]) begin
      gen2bfmDA[i] = new();
    end
  endfunction

endclass


//============================================================
// Generator
//============================================================
class mem_gen;

  mem_tx tx;
  int    gen_num;
  int    num_ops;

  function new(int i);
    gen_num = i;
    num_ops = 0;
  endfunction

  task send_write(bit [`ADDR_WIDTH-1:0] addr,
                  bit [`WIDTH-1:0]      data);
    tx       = new();
    tx.addr  = addr;
    tx.data  = data;
    tx.wr_rd = 1'b1;

    mem_common::gen2bfmDA[gen_num].put(tx);
    num_ops++;
  endtask

  task send_read(bit [`ADDR_WIDTH-1:0] addr);
    tx       = new();
    tx.addr  = addr;
    tx.data  = '0;
    tx.wr_rd = 1'b0;

    mem_common::gen2bfmDA[gen_num].put(tx);
    num_ops++;
  endtask

  task run();
    bit [`ADDR_WIDTH-1:0] rand_addr;
    bit [`WIDTH-1:0]      rand_data;

    // Directed and corner cases
    send_write(0,         16'h0000); send_read(0);
    send_write(`DEPTH-1,  16'hFFFF); send_read(`DEPTH-1);
    send_write(`DEPTH/2,  16'hA5A5); send_read(`DEPTH/2);
    send_write(10,        16'hAAAA); send_read(10);
    send_write(11,        16'h5555); send_read(11);

    // Overwrite same location
    send_write(20,        16'h1234);
    send_write(20,        16'hBEEF);
    send_read (20);

    // Adjacent addresses
    send_write(30,        16'h1111);
    send_write(31,        16'h2222);
    send_read (30);
    send_read (31);

    // Read from unwritten location
    send_read(100);

    // Edge-near addresses
    send_write(`DEPTH-2,  16'h0F0F); send_read(`DEPTH-2);
    send_write(1,         16'hF0F0); send_read(1);

    // Random write-read pairs
    repeat (80) begin
      rand_addr = $urandom_range(0, `DEPTH-1);
      rand_data = $urandom;
      send_write(rand_addr, rand_data);
      send_read(rand_addr);
    end

    $display("[%0t] GEN%0d finished. Total operations = %0d",
             $time, gen_num, num_ops);
  endtask

endclass


//============================================================
// BFM / Driver
//============================================================
class mem_bfm;

  virtual mem_intf vif;
  mem_tx           tx;
  int              bfm_num;

  function new(int i);
    vif     = mem_common::vif;
    bfm_num = i;
  endfunction

  task drive_tx(mem_tx tx);
    @(vif.bfm_cb);
    vif.bfm_cb.addr_i  <= tx.addr;
    vif.bfm_cb.wr_rd_i <= tx.wr_rd;
    vif.bfm_cb.valid_i <= 1'b1;

    if (tx.wr_rd)
      vif.bfm_cb.wdata_i <= tx.data;
    else
      vif.bfm_cb.wdata_i <= '0;

    wait (vif.bfm_cb.ready_o == 1'b1);

    // Hold request for one cycle
    @(vif.bfm_cb);

    // Synchronous read returns data one cycle later
    if (!tx.wr_rd) begin
      @(vif.bfm_cb);
      tx.data = vif.bfm_cb.rdata_o;
    end

    $display("[%0t] BFM%0d %s addr=0x%0h data=0x%0h",
             $time, bfm_num, (tx.wr_rd ? "WRITE" : "READ "),
             tx.addr, tx.data);

    // Deassert interface signals
    vif.bfm_cb.valid_i <= 1'b0;
    vif.bfm_cb.addr_i  <= '0;
    vif.bfm_cb.wr_rd_i <= '0;
    vif.bfm_cb.wdata_i <= '0;
  endtask

  task run(int n_ops);
    repeat (n_ops) begin
      mem_common::gen2bfmDA[bfm_num].get(tx);
      mem_common::smp.get(1);
      drive_tx(tx);
      mem_common::smp.put(1);
    end

    $display("[%0t] BFM%0d finished. Drove %0d ops.",
             $time, bfm_num, n_ops);
  endtask

endclass


//============================================================
// Monitor
//============================================================
class mem_mon;

  virtual mem_intf vif;
  mem_tx           tx;

  bit pending_read;
  bit [`ADDR_WIDTH-1:0] pending_addr;

  function new();
    vif          = mem_common::vif;
    pending_read = 1'b0;
    pending_addr = '0;
  endfunction

  task run();
    forever begin
      @(vif.mon_cb);

      if (vif.mon_cb.valid_i && vif.mon_cb.ready_o) begin
        if (vif.mon_cb.wr_rd_i) begin
          tx       = new();
          tx.addr  = vif.mon_cb.addr_i;
          tx.wr_rd = 1'b1;
          tx.data  = vif.mon_cb.wdata_i;

          mem_common::mon2ref.put(tx);
          mem_common::mon2cov.put(tx);

          $display("[%0t] MON captured WRITE addr=0x%0h data=0x%0h",
                   $time, tx.addr, tx.data);
        end
        else begin
          pending_read = 1'b1;
          pending_addr = vif.mon_cb.addr_i;
        end
      end
      else if (pending_read) begin
        tx       = new();
        tx.addr  = pending_addr;
        tx.wr_rd = 1'b0;
        tx.data  = vif.mon_cb.rdata_o;

        mem_common::mon2ref.put(tx);
        mem_common::mon2cov.put(tx);

        $display("[%0t] MON captured READ  addr=0x%0h data=0x%0h",
                 $time, tx.addr, tx.data);

        pending_read = 1'b0;
      end
    end
  endtask

endclass


//============================================================
// Coverage
//============================================================
class mem_cov;

  mem_tx tx;

  covergroup mem_cg;
    option.per_instance = 1;

    ADDR_CP : coverpoint tx.addr {
      bins low_addr   = {0};
      bins high_addr  = {`DEPTH-1};
      bins near_low   = {1, 2, 3};
      bins near_high  = {`DEPTH-2, `DEPTH-3};
      bins middle     = {`DEPTH/2};
      bins others     = {[4:`DEPTH-4]};
    }

    WR_RD_CP : coverpoint tx.wr_rd {
      bins read_op  = {0};
      bins write_op = {1};
    }

    DATA_CP : coverpoint tx.data iff (tx.wr_rd) {
      bins zero     = {16'h0000};
      bins all_one  = {16'hFFFF};
      bins alt_a    = {16'hAAAA};
      bins alt_5    = {16'h5555};
      bins low_pat  = {16'h0F0F, 16'h00FF};
      bins high_pat = {16'hF0F0, 16'hFF00};
      bins misc     = default;
    }

    ADDR_X_WRRD : cross ADDR_CP, WR_RD_CP;
  endgroup

  function new();
    mem_cg = new();
  endfunction

  task run();
    forever begin
      mem_common::mon2cov.get(tx);
      mem_cg.sample();
    end
  endtask

  function void report();
    $display("--------------------------------------------------");
    $display("Functional Coverage = %0.2f %%", mem_cg.get_coverage());
    $display("--------------------------------------------------");
  endfunction

endclass


//============================================================
// Scoreboard
//============================================================
class mem_sbd;

  mem_tx tx;
  bit [`WIDTH-1:0] mem_model[*];
  bit [`WIDTH-1:0] expected_data;

  task run();
    forever begin
      mem_common::mon2ref.get(tx);

      if (tx.wr_rd) begin
        mem_model[tx.addr] = tx.data;
        $display("[%0t] SBD model WRITE addr=0x%0h data=0x%0h",
                 $time, tx.addr, tx.data);
      end
      else begin
        if (mem_model.exists(tx.addr))
          expected_data = mem_model[tx.addr];
        else
          expected_data = '0;

        if (tx.data === expected_data) begin
          mem_common::num_matches++;
          $display("[%0t] SBD PASS addr=0x%0h expected=0x%0h actual=0x%0h",
                   $time, tx.addr, expected_data, tx.data);
        end
        else begin
          mem_common::num_mismatches++;
          $error("[%0t] SBD FAIL addr=0x%0h expected=0x%0h actual=0x%0h",
                 $time, tx.addr, expected_data, tx.data);
        end
      end
    end
  endtask

  function void report();
    $display("--------------------------------------------------");
    $display("Scoreboard matches    = %0d", mem_common::num_matches);
    $display("Scoreboard mismatches = %0d", mem_common::num_mismatches);
    $display("--------------------------------------------------");
  endfunction

endclass


//============================================================
// Agent
//============================================================
class mem_agent;

  mem_bfm bfm;
  mem_gen gen;
  int     agent_num;

  function new(int i);
    agent_num = i;
    bfm       = new(i);
    gen       = new(i);
  endfunction

  task run_fixed();
    gen.run();
    bfm.run(gen.num_ops);
  endtask

endclass


//============================================================
// Environment
//============================================================
class mem_env;

  mem_agent agentDA[];
  mem_mon   mon;
  mem_cov   cov;
  mem_sbd   sbd;

  function new();
    mon = new();
    cov = new();
    sbd = new();

    agentDA = new[mem_common::num_agents];
    foreach (agentDA[i]) begin
      agentDA[i] = new(i);
    end
  endfunction

  task run();
    fork
      mon.run();
      cov.run();
      sbd.run();
    join_none

    foreach (agentDA[i]) begin
      agentDA[i].run_fixed();
    end

    repeat (20) @(posedge mem_common::vif.clk_i);

    cov.report();
    sbd.report();
  endtask

endclass


//============================================================
// Top
//============================================================
module tb_top;

  logic      clk;
  logic      rst;
  mem_intf   pif(clk, rst);
  mem_env    env;
  mem_common mem_common_i;

  // Clock generation
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

  // DUT instance
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

  // Basic assertions
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
