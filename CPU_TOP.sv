// FIX: inst is 20 bits throughout (8 op + 4 rs1 + 4 rs2 + 4 rd)
module cpu_top (
    input  logic        clk,
    input  logic        rst,
    input  logic [19:0] inst,          // FIX: was [18:0]

    // Testbench observation ports
    output logic [15:0] pc_out,
    output logic [15:0] write_data,
    output logic [15:0] read_data1,
    output logic [15:0] read_data2,
    output logic [7:0]  alu_op_code
);

    //--------------------------------------------------
    // DECODE  (20-bit encoding: [19:12] op | [11:8] rs1 | [7:4] rs2 | [3:0] rd)
    //--------------------------------------------------
    logic [3:0] rs1, rs2, rd;

    assign alu_op_code = inst[19:12];
    assign rs1         = inst[11:8];
    assign rs2         = inst[7:4];
    assign rd          = inst[3:0];    // FIX: was never decoded before

    //--------------------------------------------------
    // INTERNAL
    //--------------------------------------------------
    logic [15:0] alu_result;
    logic Z, N, C, V;
    logic Zf, Nf, Cf, Vf;
    logic we, branch_en, jump_en;
    logic take_branch;

    //--------------------------------------------------
    // REGISTER FILE
    //--------------------------------------------------
    reg_file rf (
        .clk        (clk),
        .rst        (rst),
        .we         (we),
        .rs1        (rs1),
        .rs2        (rs2),
        .rd         (rd),
        .write_data (alu_result),
        .rdata1     (read_data1),
        .rdata2     (read_data2)
    );

    //--------------------------------------------------
    // ALU
    //--------------------------------------------------
    ALU alu (
        .a       (read_data1),
        .b       (read_data2),
        .op_code (alu_op_code),
        .result  (alu_result),
        .Z(Z), .N(N), .C(C), .V(V)
    );

    //--------------------------------------------------
    // FLAGS REGISTER
    //--------------------------------------------------
    flags_reg fr (
        .clk  (clk),
        .rst  (rst),
        .Z_in (Z), .N_in (N), .C_in (C), .V_in (V),
        .we   (we),
        .Z    (Zf), .N    (Nf), .C    (Cf), .V    (Vf)
    );

    //--------------------------------------------------
    // BRANCH UNIT
    //--------------------------------------------------
    branch_unit bu (
        .opcode      (alu_op_code),
        .Z           (Zf),
        .N           (Nf),
        .V           (Vf),
        .take_branch (take_branch)
    );

    //--------------------------------------------------
    // CONTROL LOGIC
    //--------------------------------------------------
    always_comb begin
        we        = 1'b0;
        branch_en = 1'b0;
        jump_en   = 1'b0;

        case (alu_op_code[7:5])
            3'b000: we        = 1'b1;   // ALU ops  (opcodes 0–31)
            3'b011: branch_en = 1'b1;   // branches (opcodes 96–127)
            3'b100: jump_en   = 1'b1;   // jumps    (opcodes 128–159)
            default: ;
        endcase
    end

    //--------------------------------------------------
    // PROGRAM COUNTER
    //--------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            pc_out <= 16'd0;
        else if (jump_en)
            pc_out <= {4'b0, inst[11:0]};
        else if (branch_en && take_branch)
            pc_out <= pc_out + {8'b0, inst[7:0]};
        else
            pc_out <= pc_out + 16'd1;
    end

    //--------------------------------------------------
    // TESTBENCH OUTPUT
    //--------------------------------------------------
    assign write_data = alu_result;

endmodule