class mem_tx;

  rand bit [`ADDR_WIDTH-1:0] addr;
  rand bit [`WIDTH-1:0]      data;
  rand bit                   wr_rd;

  function void print(string name = "mem_tx");
    $display("[%0t] %s : addr=0x%0h data=0x%0h wr_rd=%0d",
             $time, name, addr, data, wr_rd);
  endfunction

endclass
