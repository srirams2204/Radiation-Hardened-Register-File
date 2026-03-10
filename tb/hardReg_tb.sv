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
class tracsaction;
    randc logic [4:0] rd;
    rand logic [31:0] rd_data;
    rand logic [4:0] rs1, rs2;
    rand logic reg_write;
    constraint addr_range {rd < 32; rs1 < 32; rs2 < 32;}
    constraint write_dist {reg_write dist {1 := 90, 0 := 10};}

    function void display(string name);
        $display("[%s] @%0t: Write Addr=%0d | Data=%0d", name, $time, rd, rd_data);
    endfunction
endclass

// GENERATOR
class generator;
    
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
