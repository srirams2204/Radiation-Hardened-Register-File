// INTERFACE
interface hreg_if(input logic clk);
    // OUTPUT PORTS
    logic [31:0] rs1_data, rs2_data;
    // INPUT PORTS
    logic [31:0] rd_data;
    logic [4:0] rs1, rs2, rd;
    // CONTROL SIGNAL
    logic reg_write;

    // CLOCKING BLOCK
    clocking cb @(posedge clk);
        output rd_data;
        output rs1;
        output rs2;
        output rd;
        output reg_write;

        input rs1_data;
        input rs2_data;
    endclocking

    // MODPORT
    modport DUT (
        input  clk, rd_data, rs1, rs2, rd, reg_write,
        output rs1_data, rs2_data
    );

    modport TB (
        clocking cb, 
        input clk,
        input reg_write, rd, rd_data, rs1, rs2,
        output rs1_data, rs2_data
    );
endinterface 

// TRANSACTION CLASS
class transaction;
    randc logic [4:0] rd; // cyclic
    rand logic [31:0] rd_data;
    randc logic [4:0] rs1, rs2; // cyclic
    rand logic reg_write;
    logic [31:0] rs1_data;
    logic [31:0] rs2_data;
    constraint addr_range {rd < 32; rs1 < 32; rs2 < 32;}
    constraint write_dist {reg_write dist {1 := 90, 0 := 10};}

    function void display(string name);
        $display("[%s] @%0t: Write Addr=%0d | Data=%0d", name, $time, rd, rd_data);
    endfunction

    function transaction copy();
        transaction tmp; // Use a temporary handle
        tmp = new();
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

// GENERATOR
class generator;
    transaction trans;
    mailbox #(transaction) gen2drv;
    int repeat_count = 32;
    event ended;

    function new(mailbox #(transaction) gen2drv);
        this.gen2drv = gen2drv;
    endfunction

    task write_mem();
        $display("[GEN] @%0t: Starting generation for all 32 addresses...", $time);
        trans = new();
        repeat(repeat_count) begin
            if (!trans.randomize() with {reg_write == 1'b1;}) begin
                $fatal("[GEN] Randomization failed!");
            end
            trans.display("GEN");
            gen2drv.put(trans.copy());
        end
        -> ended;
        $display("[GEN] @%0t: Generation finished.", $time);
    endtask

    task read_mem();
        $display("[GEN] @%0t: Starting READ sequence for all 32 addresses...", $time);
        trans = new();
        repeat(repeat_count) begin
            if (!trans.randomize() with {reg_write == 1'b0;}) begin
                $fatal("[GEN] Randomization failed!");
            end
            
            trans.rs1 = trans.rd;
            trans.rs2 = trans.rd;
            
            gen2drv.put(trans.copy());
        end
        -> ended; 
        $display("[GEN] @%0t: Read sequence finished.", $time);
    endtask
endclass

// DRIVER
class driver;
    virtual hreg_if.TB vif;
    mailbox #(transaction) gen2drv;

    function new(virtual hreg_if.TB vif, mailbox #(transaction) gen2drv);
        this.vif = vif;
        this.gen2drv = gen2drv;
    endfunction

    task main();
        $display("[DRV] @%0t: Driver started, waiting for transactions...", $time);
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

// MONITOR
class monitor;
    virtual hreg_if.TB vif;
    mailbox #(transaction) mon2scb;
    transaction trans;

    covergroup reg_cov;
        option.per_instance = 1;
        // Did we hit all 32 addresses?
        cp_addr: coverpoint trans.rd {
            bins all_regs[] = {[0:31]};
        }
        // Did we perform both Writes and Reads?
        cp_op: coverpoint trans.reg_write {
            bins write_op = {1};
            bins read_op  = {0};
        }
        // Pro-Move: Did we do both a Read AND a Write to EVERY address?
        cross_op_addr: cross cp_op, cp_addr;
    endgroup

    function new(virtual hreg_if.TB vif, mailbox #(transaction) mon2scb);
        this.vif = vif;
        this.mon2scb = mon2scb;
        reg_cov = new(); // You MUST instantiate the covergroup!
    endfunction

    task main();
        $display("[MON] @%0t: Monitor started, watching interface...", $time);
        
        forever begin
            trans = new();
            @(vif.cb);
            #1;             
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

    // Print coverage report
    function void print_coverage();
        $display("=========================================================");
        $display(" FUNCTIONAL COVERAGE REPORT");
        $display(" Total Coverage: %0.2f%%", reg_cov.get_inst_coverage());
        $display("=========================================================\n");
    endfunction
endclass

// SCOREBOARD
class scoreboard;
    mailbox #(transaction) mon2scb;
    logic [31:0] golden_mem [0:31];
    int pass_count = 0;
    int fail_count = 0;
    bit header_printed = 0;

    function new(mailbox #(transaction) mon2scb);
        this.mon2scb = mon2scb;
        foreach(golden_mem[i]) golden_mem[i] = 32'h0;
    endfunction

    function void check_and_print(logic [4:0] addr, logic [31:0] actual_data);
        logic [31:0] expected_data = golden_mem[addr];
        assert(actual_data == expected_data) begin
            $display("|  %2d  |   %8h    |   %8h    |  PASS  |", 
                     addr, expected_data, actual_data);
            pass_count++;
        end else begin
            $display("|  %2d  |   %8h    |   %8h    |  FAIL  |", 
                     addr, expected_data, actual_data);
            fail_count++;
        end
    endfunction

    task main();
        $display("[SCB] @%0t: Scoreboard started, Golden Model ready.", $time);
        forever begin
            transaction trans;
            mon2scb.get(trans); 
            if (trans.reg_write == 1'b1) begin
                golden_mem[trans.rd] = trans.rd_data;
            end else begin
                if (!header_printed) begin
                    $display("\n=========================================================");
                    $display("| ADDR | EXPECTED DATA |  ACTUAL DATA  | STATUS |");
                    $display("=========================================================");
                    header_printed = 1;
                end
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

// ENVIRONMENT
class environment;
    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;

    mailbox #(transaction) m_gen2drv;
    mailbox #(transaction) m_mon2scb;

    virtual hreg_if.TB vif;

    function new(virtual hreg_if.TB vif);
        this.vif = vif;
        m_gen2drv = new();
        m_mon2scb = new();
        gen = new(m_gen2drv);
        drv = new(vif, m_gen2drv);
        mon = new(vif, m_mon2scb);
        scb = new(m_mon2scb);
    endfunction

    task test();
        $display("\n=========================================================");
        $display("   STARTING TMR REGISTER FILE VERIFICATION");
        $display("=========================================================\n");

        fork
            drv.main();
            mon.main();
            scb.main();
        join_none
    endtask
endclass

// FINAL BLOCK
module tb;
    logic clk;
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end

    hreg_if intf(clk);

    hard_reg DUT (
        .clk(intf.clk),
        .rd_data(intf.rd_data),
        .rs1(intf.rs1),
        .rs2(intf.rs2),
        .rd(intf.rd),
        .reg_write(intf.reg_write),
        .rs1_data(intf.rs1_data),
        .rs2_data(intf.rs2_data)
    );

    environment env;

    task inject_faults(int num_faults);
        int r_idx, b_idx, arr_idx;
        $display("\n[TB] @%0t: --- INJECTING %0d RADIATION FAULTS ---", $time, num_faults);
        
        for (int i = 0; i < num_faults; i++) begin
            r_idx   = $urandom_range(0, 31); 
            b_idx   = $urandom_range(0, 31); 
            arr_idx = $urandom_range(0, 2);  

            if (arr_idx == 0) 
                DUT.regA[r_idx][b_idx] = ~DUT.regA[r_idx][b_idx];
            else if (arr_idx == 1) 
                DUT.regB[r_idx][b_idx] = ~DUT.regB[r_idx][b_idx];
            else 
                DUT.regC[r_idx][b_idx] = ~DUT.regC[r_idx][b_idx];
            
            $display("[TB] Corrupted Array %0d | Reg %2d | Bit %2d", arr_idx, r_idx, b_idx);
        end
        $display("--------------------------------------------------\n");
    endtask

    initial begin
        env = new(intf.TB);
        env.test(); 

        // --------------------------------------------------
        // PHASE 1: WRITE GOLDEN DATA
        // --------------------------------------------------
        env.gen.write_mem();
        
        // Wait until the Driver has pulled all 32 writes from the mailbox!
        // This takes ~320ns in simulation time.
        wait(env.gen.gen2drv.num() == 0); 
        
        // Wait 3 extra clock cycles for the final write to physically settle in the RTL
        #30; 

        // --------------------------------------------------
        // PHASE 2: FAULT INJECTION
        // --------------------------------------------------
        inject_faults(15);
        #10; 

        // --------------------------------------------------
        // PHASE 3: READ AND VERIFY
        // --------------------------------------------------
        env.gen.read_mem();
        
        // Wait until the Driver has pulled all 32 reads from the mailbox!
        wait(env.gen.gen2drv.num() == 0); 

        // Give the Monitor and Scoreboard time to catch and process the final outputs
        #40; 
        
        // Print the glorious results
        env.scb.print_summary();

        env.mon.print_coverage();
        
        $finish; 
    end
    /*
    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, tb);
    end
    */
endmodule
