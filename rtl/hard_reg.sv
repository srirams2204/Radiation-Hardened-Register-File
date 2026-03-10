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

// regA = main write register
logic [31:0] regA [0:31];

// regB and regC are redundant copy
logic [31:0] regB [0:31];
logic [31:0] regC [0:31];

// Optional init for simulation
initial begin
    for (int i = 0; i < 32; i = i + 1) begin
        regA[i] = 32'b0;
        regB[i] = 32'b0;
        regC[i] = 32'b0;
    end
end

// Writing to Register
always_ff @(posedge clk) begin
    if (reg_write) begin
        regA[rd] <= rd_data;
        regB[rd] <= rd_data;
        regC[rd] <= rd_data;
    end    
end

// voting correction while read
assign rs1_data = (regA[rs1] & regB[rs1]) |
                  (regB[rs1] & regC[rs1]) |
                  (regC[rs1] & regA[rs1]);

assign rs2_data = (regA[rs2] & regB[rs2]) |
                  (regB[rs2] & regC[rs2]) |
                  (regC[rs2] & regA[rs2]);

endmodule
