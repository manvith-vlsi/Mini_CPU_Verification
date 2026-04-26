module branch_unit (
    input  logic [7:0] opcode,
    input  logic Z, N, V,
    output logic take_branch
);

    always_comb begin
        take_branch = 1'b0;

        case (opcode)
            8'h20: take_branch =  Z;             // BEQ
            8'h21: take_branch = ~Z;             // BNE
            8'h22: take_branch = (N != V);       // BLT
            8'h23: take_branch = (~Z && (N == V)); // BGT
            default: take_branch = 1'b0;
        endcase
    end

endmodule