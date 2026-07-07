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

    @(vif.bfm_cb);

    if (!tx.wr_rd) begin
      @(vif.bfm_cb);
      tx.data = vif.bfm_cb.rdata_o;
    end

    $display("[%0t] BFM%0d %s addr=0x%0h data=0x%0h",
             $time, bfm_num, (tx.wr_rd ? "WRITE" : "READ "),
             tx.addr, tx.data);

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
