// ============================================================================
// INTERFACE
// ============================================================================
interface hreg_if(input logic clk);
    logic [31:0] rs1_data, rs2_data;
    logic [31:0] rd_data;
    logic [4:0] rs1, rs2, rd;
    logic reg_write;

    clocking cb @(posedge clk);
        output rd_data, rs1, rs2, rd, reg_write;
        input rs1_data, rs2_data;
    endclocking

    modport DUT (
        input  clk, rd_data, rs1, rs2, rd, reg_write,
        output rs1_data, rs2_data
    );

    modport TB (
        clocking cb, 
        input clk, reg_write, rd, rd_data, rs1, rs2, rs1_data, rs2_data
    );
endinterface 

// ============================================================================
// TRANSACTION CLASS
// ============================================================================
class transaction;
    randc logic [4:0] rd; 
    rand logic [31:0] rd_data;
    randc logic [4:0] rs1, rs2; 
    rand logic reg_write;
    logic [31:0] rs1_data, rs2_data;
    
    constraint addr_range {rd < 32; rs1 < 32; rs2 < 32;}
    constraint write_dist {reg_write dist {1 := 90, 0 := 10};}

    function transaction copy();
        transaction tmp = new();
        tmp.rd = this.rd;
        tmp.rd_data = this.rd_data;
        tmp.rs1 = this.rs1;
        tmp.rs2 = this.rs2;
        tmp.reg_write = this.reg_write;
        tmp.rs1_data = this.rs1_data;
        tmp.rs2_data = this.rs2_data;
        return tmp;   
    endfunction
endclass

// ============================================================================
// GENERATOR
// ============================================================================
class generator;
    transaction trans;
    mailbox #(transaction) gen2drv;
    int repeat_count = 32;

    function new(mailbox #(transaction) gen2drv);
        this.gen2drv = gen2drv;
    endfunction

    task write_mem();
        trans = new();
        repeat(repeat_count) begin
            if (!trans.randomize() with {reg_write == 1'b1;}) $fatal("[GEN] Rand failed!");
            gen2drv.put(trans.copy());
        end
    endtask

    task read_mem();
        trans = new();
        repeat(repeat_count) begin
            if (!trans.randomize() with {reg_write == 1'b0;}) $fatal("[GEN] Rand failed!");
            gen2drv.put(trans.copy());
        end
    endtask

    task read_single(logic [4:0] target_addr);
        trans = new();
        if (!trans.randomize() with {reg_write == 1'b0;}) $fatal("[GEN] Rand failed!");
        trans.rs1 = target_addr;
        trans.rs2 = target_addr;
        gen2drv.put(trans.copy());
    endtask
endclass

// ============================================================================
// DRIVER
// ============================================================================
class driver;
    virtual hreg_if.TB vif;
    mailbox #(transaction) gen2drv;

    function new(virtual hreg_if.TB vif, mailbox #(transaction) gen2drv);
        this.vif = vif;
        this.gen2drv = gen2drv;
    endfunction

    task main();
        forever begin
            transaction trans;
            gen2drv.get(trans);
            @(vif.cb);
            vif.cb.reg_write <= trans.reg_write;
            vif.cb.rd <= trans.rd;
            vif.cb.rd_data <= trans.rd_data;
            vif.cb.rs1 <= trans.rs1;
            vif.cb.rs2 <= trans.rs2;
        end
    endtask
endclass

// ============================================================================
// MONITOR
// ============================================================================
class monitor;
    virtual hreg_if.TB vif;
    mailbox #(transaction) mon2scb;
    transaction trans;

    covergroup reg_cov;
        option.per_instance = 1;
        cp_addr: coverpoint trans.rd { bins all_regs[] = {[0:31]}; }
        cp_op: coverpoint trans.reg_write { bins write_op = {1}; bins read_op = {0}; }
        cross_op_addr: cross cp_op, cp_addr;
    endgroup

    function new(virtual hreg_if.TB vif, mailbox #(transaction) mon2scb);
        this.vif = vif;
        this.mon2scb = mon2scb;
        reg_cov = new(); 
    endfunction

    task main();
        forever begin
            trans = new();
            @(vif.cb);
            #1; // Combinational delay logic
            trans.reg_write = vif.reg_write;
            trans.rd        = vif.rd;
            trans.rd_data   = vif.rd_data;
            trans.rs1       = vif.rs1;
            trans.rs2       = vif.rs2;
            trans.rs1_data  = vif.rs1_data; 
            trans.rs2_data  = vif.rs2_data; 
            reg_cov.sample();
            mon2scb.put(trans);
        end
    endtask

    function void print_coverage();
        $display("=========================================================");
        $display(" FUNCTIONAL COVERAGE REPORT: %0.2f%%", reg_cov.get_inst_coverage());
        $display("=========================================================\n");
    endfunction
endclass

// ============================================================================
// SCOREBOARD
// ============================================================================
class scoreboard;
    mailbox #(transaction) mon2scb;
    logic [31:0] golden_mem [0:31];
    int pass_count = 0;
    int fail_count = 0;
    bit verbose = 0; // Set to 1 to print EVERY pass, 0 to print only FAILS
    bit header_printed = 0;

    function new(mailbox #(transaction) mon2scb);
        this.mon2scb = mon2scb;
        foreach(golden_mem[i]) golden_mem[i] = 32'h0;
    endfunction

    function void check_and_print(logic [4:0] addr, logic [31:0] actual_data);
        logic [31:0] expected_data = golden_mem[addr];
        
        if (!header_printed && (verbose || actual_data != expected_data)) begin
            $display("\n=========================================================");
            $display("| ADDR | EXPECTED DATA |  ACTUAL DATA  | STATUS |");
            $display("=========================================================");
            header_printed = 1;
        end

        assert(actual_data == expected_data) begin
            if (verbose) $display("|  %2d  |   %8h    |   %8h    |  PASS  |", addr, expected_data, actual_data);
            pass_count++;
        end else begin
            $display("|  %2d  |   %8h    |   %8h    | *FAIL* |", addr, expected_data, actual_data);
            fail_count++;
        end
    endfunction

    task main();
        forever begin
            transaction trans;
            mon2scb.get(trans); 
            if (trans.reg_write == 1'b1) begin
                golden_mem[trans.rd] = trans.rd_data;
            end else begin
                check_and_print(trans.rs1, trans.rs1_data);
                check_and_print(trans.rs2, trans.rs2_data);
            end
        end
    endtask

    function void print_summary();
        $display("=========================================================");
        $display(" FINAL SCOREBOARD SUMMARY: %0d PASS / %0d FAIL", pass_count, fail_count);
        $display("=========================================================\n");
    endfunction
endclass

// ============================================================================
// ENVIRONMENT
// ============================================================================
class environment;
    generator gen; driver drv; monitor mon; scoreboard scb;
    mailbox #(transaction) m_gen2drv, m_mon2scb;
    virtual hreg_if.TB vif;

    function new(virtual hreg_if.TB vif);
        this.vif = vif;
        m_gen2drv = new(); m_mon2scb = new();
        gen = new(m_gen2drv); drv = new(vif, m_gen2drv);
        mon = new(vif, m_mon2scb); scb = new(m_mon2scb);
    endfunction

    task test();
        fork drv.main(); mon.main(); scb.main(); join_none
    endtask
endclass

// ============================================================================
// TOP LEVEL TESTBENCH MODULE
// ============================================================================
module tb;
    logic clk;
    initial begin clk = 0; forever #5 clk = ~clk; end

    hreg_if intf(clk);

    hard_reg DUT (
        .clk(intf.clk), .rd_data(intf.rd_data), .rs1(intf.rs1), .rs2(intf.rs2),
        .rd(intf.rd), .reg_write(intf.reg_write), .rs1_data(intf.rs1_data), .rs2_data(intf.rs2_data)
    );

    environment env;

    // --- HELPER TASK: TABULAR MEMORY DUMP ---
    task display_memory_state(string scenario_name);
        int i;          // Static declaration for VCS
        string status;  // Static declaration for VCS
        
        $display("\n===========================================================================");
        $display(" MEMORY DUMP: %s", scenario_name);
        $display("===========================================================================");
        $display("| ADDR |      regA      |      regB      |      regC      |   STATUS  |");
        $display("===========================================================================");
        
        for (i = 0; i < 32; i++) begin
            status = (DUT.regA[i] == DUT.regB[i] && DUT.regB[i] == DUT.regC[i]) ? "  OK  " : "*FAULT*";
            $display("|  %2d  |   %8h   |   %8h   |   %8h   |  %s |", 
                     i, DUT.regA[i], DUT.regB[i], DUT.regC[i], status);
        end
        $display("===========================================================================\n");
    endtask

    // --- SCENARIO 1: EXHAUSTIVE SEU ---
    task exhaustive_seu_test();
        int arr, r, b; 
        logic [31:0] orig_val, bad_val;
        
        $display("\n[TB] @%0t: === SCENARIO 1: EXHAUSTIVE SEU CAMPAIGN ===", $time);
        $display(" Injecting and verifying 3,072 individual bit-flips...\n");
        
        for (arr = 0; arr < 3; arr++) begin
            for (r = 0; r < 32; r++) begin
                for (b = 0; b < 32; b++) begin
                    // Capture original value
                    if (arr == 0) orig_val = DUT.regA[r];
                    else if (arr == 1) orig_val = DUT.regB[r];
                    else orig_val = DUT.regC[r];

                    // Inject Fault
                    if (arr == 0) DUT.regA[r][b] = ~DUT.regA[r][b];
                    else if (arr == 1) DUT.regB[r][b] = ~DUT.regB[r][b];
                    else DUT.regC[r][b] = ~DUT.regC[r][b];
                    
                    // Capture corrupted value
                    if (arr == 0) bad_val = DUT.regA[r];
                    else if (arr == 1) bad_val = DUT.regB[r];
                    else bad_val = DUT.regC[r];

                    // Print the exact corruption in Hex
                    $display("[SEU] Array %0d | Addr %2d | Bit %2d flipped | Orig: %8h -> Bad: %8h", arr, r, b, orig_val, bad_val);
                    
                    if (arr == 0 && r == 0 && b < 3) begin
                        env.scb.verbose = 1; 
                    end else begin
                        env.scb.verbose = 0; 
                    end

                    // Verify TMR masks it
                    env.gen.read_single(r); 
                    wait(env.gen.gen2drv.num() == 0); 
                    #15; 
                    
                    // Heal the Fault
                    if (arr == 0) DUT.regA[r][b] = ~DUT.regA[r][b];
                    else if (arr == 1) DUT.regB[r][b] = ~DUT.regB[r][b];
                    else DUT.regC[r][b] = ~DUT.regC[r][b];
                end
            end
        end
    endtask

    // --- SCENARIO 2: DOUBLE EVENT UPSET (DEU) ---
    task scenario_2_deu();
        int r_idx, b_idx, i;
        $display("\n[TB] @%0t: === SCENARIO 2: DEU (SAME ADDRESS, 2 ARRAYS) ===", $time);
        
        for (i = 0; i < 5; i++) begin
            r_idx = $urandom_range(0, 31); 
            b_idx = $urandom_range(0, 31); 
            
            // Corrupt BOTH regA and regB at the exact same bit!
            DUT.regA[r_idx][b_idx] = ~DUT.regA[r_idx][b_idx];
            DUT.regB[r_idx][b_idx] = ~DUT.regB[r_idx][b_idx];
        end
    endtask

    // --- SCENARIO 3: TWO FULL ARRAYS FAIL ---
    task scenario_3_double_array_fail();
        int i;
        $display("\n[TB] @%0t: === SCENARIO 3: TOTAL COLLAPSE (2 ARRAYS DESTROYED) ===", $time);
        
        for (i = 0; i < 32; i++) begin
            // Fill both regA and regC with complete garbage
            DUT.regA[i] = $urandom();
            DUT.regC[i] = $urandom();
        end
    endtask

    // --- MASTER TIMELINE ---
    initial begin
        env = new(intf.TB);
        env.scb.verbose = 0; // Keep Scoreboard quiet for the exhaustive loop
        
        // --- BASELINE ---
        env.test(); 
        env.gen.write_mem();
        wait(env.gen.gen2drv.num() == 0); 
        #30; 

        // ==========================================
        // RUN SCENARIO 1 (Exhaustive)
        // ==========================================
        exhaustive_seu_test();

        // ==========================================
        // RUN SCENARIO 2 (DEU)
        // ==========================================
        scenario_2_deu();
        display_memory_state("SCENARIO 2: DEU INJECTED (TMR WILL FAIL)");
        
        $display("[TB] Reading memory to verify TMR voter failure...");
        env.scb.verbose = 1; // Turn Scoreboard printing ON so we see the FAILs
        env.gen.read_mem(); 
        wait(env.gen.gen2drv.num() == 0); 
        #25; 

        // HEAL MEMORY BETWEEN SCENARIOS
        env.scb.verbose = 0;
        env.gen.write_mem();
        wait(env.gen.gen2drv.num() == 0); 
        #30; 

        // ==========================================
        // RUN SCENARIO 3 (Total Collapse)
        // ==========================================
        scenario_3_double_array_fail();
        display_memory_state("SCENARIO 3: REG-A & REG-C TOTALLY DESTROYED");
        
        $display("[TB] Reading memory... prepare for massive failures...");
        env.scb.verbose = 1; 
        env.gen.read_mem(); 
        wait(env.gen.gen2drv.num() == 0); 
        #25; 

        // ==========================================
        // FINAL RESULTS
        // ==========================================
        env.scb.print_summary();
        env.mon.print_coverage();
        
        $finish; 
    end
endmodule