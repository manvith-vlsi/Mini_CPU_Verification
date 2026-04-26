module ALU (
    input  logic [15:0] a,
    input  logic [15:0] b,
    input  logic [7:0]  op_code,
    output logic [15:0] result,
    output logic Z, N, C, V
);

    logic [16:0] temp;

    always_comb begin
        result = 16'd0;
        temp   = 17'd0;
        C = 0;
        V = 0;

        unique case (op_code)

            8'd0: begin // ADD
                temp   = {1'b0, a} + {1'b0, b};
                result = temp[15:0];
                C = temp[16];
                V = (a[15] == b[15]) && (result[15] != a[15]);
            end

            8'd1: begin // SUB
                temp   = {1'b0, a} - {1'b0, b};
                result = temp[15:0];
                C = temp[16];
                V = (a[15] != b[15]) && (result[15] != a[15]);
            end

            8'd2:  result = a * b;                         // MUL (lower 16 bits)
            8'd3:  result = ~a;                            // NOT a
            8'd4:  result = (b != 0) ? (a / b) : 16'd0;   // DIV (guard /0)
            8'd5:  result = a & b;                         // AND
            8'd6:  result = a | b;                         // OR
            8'd7:  result = ~(a & b);                      // NAND
            8'd8:  result = ~(a | b);                      // NOR
            8'd9:  result = a ^ b;                         // XOR
            8'd10: result = ~(a ^ b);                      // XNOR
            8'd11: result = a << b[3:0];                   // LSL
            8'd12: result = a >> b[3:0];                   // LSR
            8'd13: result = 16'($signed(a) >>> b[3:0]);    // ASR
            8'd14: result = 16'($signed(a) <<< b[3:0]);    // ASL
            8'd15: result = (a < b) ? 16'd1 : 16'd0;      // SLT

            default: result = 16'd0;

        endcase

        Z = (result == 16'd0);
        N =  result[15];

    end

endmodule