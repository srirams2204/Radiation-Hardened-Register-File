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