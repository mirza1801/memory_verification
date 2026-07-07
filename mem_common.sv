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
