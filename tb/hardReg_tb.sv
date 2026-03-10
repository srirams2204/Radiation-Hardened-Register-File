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
        input clk   
    );
endinterface 

// TRANSACTION CLASS
class transaction;
    randc logic [4:0] rd;
    rand logic [31:0] rd_data;
    rand logic [4:0] rs1, rs2;
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
endclass

// DRIVER
class driver;
    
endclass

// MONITOR
class monitor;

endclass
// SCOREBOARD

// ENVIRONMENT
module tb;

endmodule
