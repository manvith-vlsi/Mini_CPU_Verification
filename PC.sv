module PC (
    input  logic        clk, rst,
    input  logic        branch, jump,
    input  logic [7:0]  offset,
    input  logic [11:0] jaddr,
    output logic [15:0] pc
);

    always_ff @(posedge clk or posedge rst) begin
        if      (rst)    pc <= 16'd0;
        else if (jump)   pc <= {4'b0, jaddr};
        else if (branch) pc <= pc + {8'b0, offset};
        else             pc <= pc + 16'd1;
    end

endmodule