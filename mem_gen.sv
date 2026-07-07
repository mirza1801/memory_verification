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

    send_write(0,         16'h0000); send_read(0);
    send_write(`DEPTH-1,  16'hFFFF); send_read(`DEPTH-1);
    send_write(`DEPTH/2,  16'hA5A5); send_read(`DEPTH/2);
    send_write(10,        16'hAAAA); send_read(10);
    send_write(11,        16'h5555); send_read(11);

    send_write(20,        16'h1234);
    send_write(20,        16'hBEEF);
    send_read (20);

    send_write(30,        16'h1111);
    send_write(31,        16'h2222);
    send_read (30);
    send_read (31);

    send_read(100);

    send_write(`DEPTH-2,  16'h0F0F); send_read(`DEPTH-2);
    send_write(1,         16'hF0F0); send_read(1);

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
