`timescale 1ns/1ps

//--------------------------------------------------
// Interface  — FIX: inst is 20 bits everywhere
//--------------------------------------------------
interface cpu_if (input logic clk);

    logic        rst;
    logic [19:0] inst;          // FIX: was [18:0]

    logic [15:0] pc_out;
    logic [15:0] write_data;
    logic [15:0] read_data1;
    logic [15:0] read_data2;
    logic [7:0]  alu_op_code;

endinterface


//--------------------------------------------------
// Transaction
//--------------------------------------------------
class transaction;

    // Observed outputs
    logic [15:0] pc;
    logic [15:0] write_data;
    logic [15:0] a;
    logic [15:0] b;
    logic [7:0]  op_code;

    // Stimulus fields
    rand logic [3:0] rs1;
    rand logic [3:0] rs2;
    rand logic [3:0] rd;       // FIX: add rd so writes actually land
    rand logic [7:0] op_rand;

    // FIX: constrain to ops the scoreboard can verify (0–15)
    constraint valid_ops {
        op_rand inside {[8'd0 : 8'd15]};
    }

    // FIX: keep rd != 0 so reg_file write-enable guard doesn't block every write
    constraint nonzero_rd {
        rd != 4'd0;
    }

    // FIX: rs1 / rs2 also non-zero so we read meaningful register values
    constraint nonzero_rs {
        rs1 != 4'd0;
        rs2 != 4'd0;
    }

    logic [19:0] inst;          // FIX: was [18:0]

    // FIX: 20-bit encoding: {op[7:0], rs1[3:0], rs2[3:0], rd[3:0]}
    function void build_inst();
        inst = {op_rand, rs1, rs2, rd};
    endfunction

endclass


//--------------------------------------------------
// Driver
//--------------------------------------------------
class driver;

    virtual cpu_if vif;

    function new(virtual cpu_if vif);
        this.vif = vif;
    endfunction

    // FIX: reset is its own task; run() must not start until reset is done
    task reset();
        $display("[DRIVER] Resetting...");
        vif.rst  = 1'b1;
        vif.inst = 20'd0;
        repeat(2) @(posedge vif.clk);
        vif.rst  = 1'b0;
        @(posedge vif.clk);
        $display("[DRIVER] Reset complete.");
    endtask

    task run();
        transaction tr;
        forever begin
            @(negedge vif.clk);

            tr = new();
            assert(tr.randomize()) else $fatal(1, "Randomize failed");
            tr.build_inst();

            vif.inst = tr.inst;

            $display("[DRV] OP=%0d RS1=%0d RS2=%0d RD=%0d",
                      tr.op_rand, tr.rs1, tr.rs2, tr.rd);
        end
    endtask

endclass


//--------------------------------------------------
// Monitor + Coverage
//--------------------------------------------------
class monitor;

    virtual cpu_if vif;
    mailbox #(transaction) mbx;

    covergroup cg;

        // All 16 ALU opcodes hit
        OP_CP: coverpoint vif.alu_op_code {
            bins all_ops[] = {[0:15]};
        }

        // Operand range buckets
        A_CP: coverpoint vif.read_data1 {
            bins zero = {0};
            bins low  = {[1:10]};
            bins mid  = {[11:100]};
            bins high = {[101:16'hFFFF]};
        }

        B_CP: coverpoint vif.read_data2 {
            bins zero = {0};
            bins low  = {[1:10]};
            bins mid  = {[11:100]};
            bins high = {[101:16'hFFFF]};
        }

        // Edge-case operands
        A_EDGE: coverpoint vif.read_data1 {
            bins zero = {16'h0000};
            bins max  = {16'hFFFF};
        }

        B_EDGE: coverpoint vif.read_data2 {
            bins zero = {16'h0000};
            bins max  = {16'hFFFF};
        }

        // Cross: every op with every operand edge value
        OP_A_CROSS: cross OP_CP, A_EDGE;
        OP_B_CROSS: cross OP_CP, B_EDGE;

    endgroup

    function new(virtual cpu_if vif, mailbox #(transaction) mbx);
        this.vif = vif;
        this.mbx = mbx;
        cg = new();
    endfunction

    task run();
        transaction tr;

        // Skip the two reset cycles
        repeat(3) @(posedge vif.clk);

        forever begin
            @(posedge vif.clk);
            #1; // let combinational outputs settle

            // Skip any cycle that still has X/Z on key signals
            if (^vif.read_data1  === 1'bx ||
                ^vif.read_data2  === 1'bx ||
                ^vif.write_data  === 1'bx ||
                ^vif.alu_op_code === 1'bx)
                continue;

            tr = new();
            tr.pc         = vif.pc_out;
            tr.a          = vif.read_data1;
            tr.b          = vif.read_data2;
            tr.op_code    = vif.alu_op_code;
            tr.write_data = vif.write_data;

            cg.sample();

            $display("[MON] OP=%0d A=%0d B=%0d RESULT=%0d",
                      tr.op_code, tr.a, tr.b, tr.write_data);

            mbx.put(tr);
        end
    endtask

endclass


//--------------------------------------------------
// Scoreboard  — FIX: handle all 16 opcodes
//--------------------------------------------------
class scoreboard;

    mailbox #(transaction) mbx;
    int pass_cnt = 0;
    int fail_cnt = 0;

    function new(mailbox #(transaction) mbx);
        this.mbx = mbx;
    endfunction

    function logic [15:0] compute_expected(transaction tr);
        logic [15:0] a, b;
        logic [16:0] tmp;
        a = tr.a;
        b = tr.b;

        case (tr.op_code)
            8'd0:  begin tmp = {1'b0,a} + {1'b0,b}; return tmp[15:0]; end  // ADD
            8'd1:  begin tmp = {1'b0,a} - {1'b0,b}; return tmp[15:0]; end  // SUB
            8'd2:  return a * b;                                             // MUL
            8'd3:  return ~a;                                                // NOT
            8'd4:  return (b != 0) ? (a / b) : 16'd0;                       // DIV
            8'd5:  return a & b;                                             // AND
            8'd6:  return a | b;                                             // OR
            8'd7:  return ~(a & b);                                          // NAND
            8'd8:  return ~(a | b);                                          // NOR
            8'd9:  return a ^ b;                                             // XOR
            8'd10: return ~(a ^ b);                                          // XNOR
            8'd11: return a << b[3:0];                                       // LSL
            8'd12: return a >> b[3:0];                                       // LSR
            8'd13: return 16'($signed(a) >>> b[3:0]);                        // ASR
            8'd14: return 16'($signed(a) <<< b[3:0]);                        // ASL
            8'd15: return (a < b) ? 16'd1 : 16'd0;                          // SLT
            default: return 16'd0;
        endcase
    endfunction

    task run();
        transaction tr;
        logic [15:0] expected;

        forever begin
            mbx.get(tr);
            expected = compute_expected(tr);

            if (tr.write_data === expected) begin
                $display("[PASS] OP=%0d A=%0d B=%0d EXP=%0d GOT=%0d",
                          tr.op_code, tr.a, tr.b, expected, tr.write_data);
                pass_cnt++;
            end else begin
                $display("[FAIL] OP=%0d A=%0d B=%0d EXP=%0d GOT=%0d",
                          tr.op_code, tr.a, tr.b, expected, tr.write_data);
                fail_cnt++;
            end
        end
    endtask

endclass


//--------------------------------------------------
// Environment  — FIX: sequential reset then run
//--------------------------------------------------
class environment;

    driver     drv;
    monitor    mon;
    scoreboard sb;

    mailbox #(transaction) mbx;
    virtual cpu_if vif;

    function new(virtual cpu_if vif);
        this.vif = vif;
        mbx = new();
        drv = new(vif);
        mon = new(vif, mbx);
        sb  = new(mbx);
    endfunction

    task run();
        // FIX: complete reset BEFORE launching stimulus, then fork the rest
        drv.reset();

        fork
            drv.run();
            mon.run();
            sb.run();
        join_none
    endtask

endclass


//--------------------------------------------------
// Testbench Top
//--------------------------------------------------
module cpu_tb;

    logic clk;
    initial clk = 1'b0;
    always #5 clk = ~clk;

    cpu_if vif (clk);

    cpu_top dut (
        .clk         (clk),
        .rst         (vif.rst),
        .inst        (vif.inst),
        .pc_out      (vif.pc_out),
        .write_data  (vif.write_data),
        .read_data1  (vif.read_data1),
        .read_data2  (vif.read_data2),
        .alu_op_code (vif.alu_op_code)
    );

    environment env;

    initial begin
        env = new(vif);
        env.run();

        #10000; // run for 10 µs (1000 cycles at 10 ns period)

        $display("\n========= FUNCTIONAL COVERAGE =========");
        $display("Coverage    = %0.2f %%", env.mon.cg.get_coverage());
        $display("PASS count  = %0d",      env.sb.pass_cnt);
        $display("FAIL count  = %0d",      env.sb.fail_cnt);
        $display("========================================\n");

        $finish;
    end

endmodule