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
