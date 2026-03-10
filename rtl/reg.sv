`timescale 1ns/1ps
module register_file (
    // OUTPUT PORTS
    output logic [31:0] rs1_data,
    output logic [31:0] rs2_data,
    // INPUT PORTS
    input logic [31:0] rd_data,
    input logic [4:0] rs1, rs2, rd,
    // GLOBAL SIGNAL
    input logic clk,
    // CONTROL
    input logic reg_write
);

logic [31:0] register [0:31];

// register file read
assign rs1_data = (rs1 == 5'd0) ? 32'b0 : register[rs1];
assign rs2_data = (rs2 == 5'd0) ? 32'b0 : register[rs2];

// register file write
always_ff @(posedge clk) begin
    if (reg_write) begin
        register[rd] <= rd_data;
    end
end

endmodule
