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
