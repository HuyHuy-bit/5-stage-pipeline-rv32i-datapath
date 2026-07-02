// if_id_reg.sv - latches fetched instruction + PC into the ID stage.
module if_id_reg (
    input  logic        clk,
    input  logic        rst,
    input  logic         flush,      // squash on taken branch/jump (control hazard)
    input  logic         stall,      // hold contents (load-use hazard - added Step 3)
    input  logic [31:0] pc_in,
    input  logic [31:0] pc_plus4_in,
    input  logic [31:0] instr_in,

    output logic [31:0] pc_out,
    output logic [31:0] pc_plus4_out,
    output logic [31:0] instr_out
);
    always_ff @(posedge clk) begin
        if (rst || flush) begin
            pc_out       <= 32'd0;
            pc_plus4_out <= 32'd0;
            instr_out    <= 32'd0;      // all-zero = illegal opcode -> control.sv default -> NOP-like (no writes)
        end else if (!stall) begin
            pc_out       <= pc_in;
            pc_plus4_out <= pc_plus4_in;
            instr_out    <= instr_in;
        end
        // else: stall holds current values (do nothing)
    end
endmodule