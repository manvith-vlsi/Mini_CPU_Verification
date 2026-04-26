# Mini CPU — RTL Design + Verification in SystemVerilog

A 16-bit non-pipelined CPU built from scratch in SystemVerilog, 
with a complete self-checking verification environment. 
Simulated and verified in Vivado.


## CPU Architecture

| Module | File | Description |
|---|---|---|
| Top level | CPU_TOP.sv | Connects all modules |
| Control Unit | CU.sv | Decodes instruction, generates control signals |
| ALU | ALU.sv | 20+ arithmetic and logical operations |
| Register File | REG.sv | 16x 16-bit registers |
| Program Counter | PC.sv | Supports sequential, branch, jump |


### Instruction Encoding (19-bit)

[18:11] — 8-bit opcode
[10:7]  — 4-bit rs1 (source register 1)
[6:3]   — 4-bit rs2 (source register 2)
[2:0]   — 3-bit padding


### ALU Operations
ADD, SUB, MUL, DIV, AND, OR, NAND, NOR, XOR, XNOR,
LEFT SHIFT, RIGHT SHIFT, arithmetic shifts,
LT, LTE, GT, GTE, EQ, NEQ, MOD, COPY


## Verification Environment

Built using SystemVerilog OOP — same architecture as UVM.
┌─────────────────────────────────────┐
│            Environment              │
│                                     │
│  ┌────────┐          ┌───────────┐  │
│  │ Driver │          │  Monitor  │  │
│  └───┬────┘          └─────┬─────┘  │
│      │                     │        │
│      ▼                     ▼        │
│  ┌────────┐          ┌───────────┐  │
│  │  DUT   │          │  Mailbox  │  │
│  └────────┘          └─────┬─────┘  │
│                             │       │
│                      ┌──────▼─────┐ │
│                      │ Scoreboard │ │
│                      └────────────┘ │
└─────────────────────────────────────┘


| Component | Role |
|---|---|
| Transaction | Defines stimulus and response object |
| Driver | Applies constrained-random instructions to DUT via virtual interface |
| Monitor | Samples DUT outputs at correct clock edge |
| Mailbox | Passes observed transactions to Scoreboard |
| Scoreboard | Computes expected result and compares against DUT output |
| Environment | Wraps all components in a clean hierarchy |

### Stimulus
- Constrained random opcodes: ADD (0), SUB (1), AND (5)
- Random source registers: rs1, rs2 from [0:15]
- 19-bit instruction packed as `{op_rand, rs1, rs2, 3'b0}`


## Bugs Caught by the Testbench

1. **Instruction field misalignment** — Driver packed rs1 at [10:7] 
   but RTL decoded from [7:4] — wrong register read every cycle
2. **Multiple drivers on same net** — Two always_comb blocks in CU 
   both drove alu_op_code — second block silently overwrote first
3. **Monitor timing issue** — Second @posedge captured result from 
   the following instruction, not the current one
4. **Wrong opcode slice in CU** — ALU case read inst[15:8] instead 
   of inst[18:11], giving garbage opcodes
5. **build_inst bit width** — Concatenation produced 24 bits, 
   truncated to 19, losing opcode bits


## Simulation Results

- All transactions passing
- Verified correct two's complement arithmetic
- ADD, SUB, AND operations confirmed across random register pairs
- 500ns simulation, ~48 transactions


## Tools

- Language: SystemVerilog
- Simulator: Vivado 2024 (Behavioral Simulation)
- Target device: xc7a12tcpg238-1


## Next Steps

- [ ] Functional coverage groups
- [ ] Assertion-based verification (SVA)
- [ ] Migrate to UVM


## File Structure

├── CPU_TOP.sv      — top level
├── CU.sv           — control unit
├── ALU.sv          — arithmetic logic unit
├── REG.sv          — register file
├── PC.sv           — program counter
└── TESTBENCH.sv    — full verification environment