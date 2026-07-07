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
