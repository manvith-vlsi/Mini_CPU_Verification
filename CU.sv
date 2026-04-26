module cu (
    input  logic [19:0] inst,
    output logic [7:0]  alu_op,
    output logic        reg_write,
    output logic        branch,
    output logic        jump
);

    always_comb begin
        alu_op   = inst[19:12];
        reg_write = 0;
        branch    = 0;
        jump      = 0;

        unique case (inst[19:17])

            3'b000: reg_write = 1; // ALU
            3'b011: branch    = 1;
            3'b100: jump      = 1;

        endcase
    end

endmodule