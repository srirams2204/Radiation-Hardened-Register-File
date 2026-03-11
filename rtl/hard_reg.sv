module hard_reg(
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

(* dont_touch = "true" *) reg [31:0] regA [0:31];
(* dont_touch = "true" *) reg [31:0] regB [0:31];
(* dont_touch = "true" *) reg [31:0] regC [0:31];

logic weA, weB, weC;

assign weA = reg_write;
assign weB = reg_write;
assign weC = reg_write;

always @(posedge clk) begin
    if (weA) regA[rd] <= rd_data;
    if (weB) regB[rd] <= rd_data;
    if (weC) regC[rd] <= rd_data;
end

// voting correction while read
assign rs1_data = (regA[rs1] & regB[rs1]) |
                  (regB[rs1] & regC[rs1]) |
                  (regC[rs1] & regA[rs1]);

assign rs2_data = (regA[rs2] & regB[rs2]) |
                  (regB[rs2] & regC[rs2]) |
                  (regC[rs2] & regA[rs2]);

endmodule