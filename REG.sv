module reg_file (
    input  logic        clk,
    input  logic        rst,
    input  logic        we,
    input  logic [3:0]  rs1, rs2, rd,
    input  logic [15:0] write_data,
    output logic [15:0] rdata1, rdata2
);

    logic [15:0] regs [0:15];
    integer i;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            // FIX: initialise to known non-zero values so operands
            // are predictable; use index+1 to keep them small & distinct.
            for (i = 0; i < 16; i++)
                regs[i] <= 16'(i + 1);
        end
        else if (we && rd != 4'd0)   // r0 is hardwired read-only
            regs[rd] <= write_data;
    end

    assign rdata1 = regs[rs1];
    assign rdata2 = regs[rs2];

endmodule