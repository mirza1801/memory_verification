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
