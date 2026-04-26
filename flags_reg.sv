module flags_reg (
    input  logic clk, rst,
    input  logic Z_in, N_in, C_in, V_in,
    input  logic we,
    output logic Z, N, C, V
);

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            Z <= 1'b0;
            N <= 1'b0;
            C <= 1'b0;
            V <= 1'b0;
        end
        else if (we) begin
            Z <= Z_in;
            N <= N_in;
            C <= C_in;
            V <= V_in;
        end
    end

endmodule