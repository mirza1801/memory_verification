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
