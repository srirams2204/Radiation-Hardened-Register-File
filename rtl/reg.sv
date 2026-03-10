`timescale 1ns/1ps
module register_file (
    output [31:0] rs1_data,
    output [31:0] rs2_data,
    input [31:0] rd_data,
    input [4:0] rs1, rs2, rd,
    input clk,
    input reg_write
);

(* ram_style = "distributed" *) reg [31:0] register [0:31];

// Optional init for simulation
integer i;
initial begin
    for (i = 0; i < 32; i = i + 1)
        register[i] = 32'b0;
end

assign rs1_data = (rs1 == 5'd0) ? 32'b0 : register[rs1];
assign rs2_data = (rs2 == 5'd0) ? 32'b0 : register[rs2];

always @(posedge clk) begin
    // Write
    if (reg_write && (rd != 5'd0))
        register[rd] <= rd_data;
end

endmodule
