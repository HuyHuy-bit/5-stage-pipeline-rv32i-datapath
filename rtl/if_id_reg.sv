`default_nettype none

// if_id_reg.sv - latches fetched instruction + PC into the ID stage.
module if_id_reg (
    input  var logic        clk,
    input  var logic        rst,
    input  var logic        flush,      // squash on taken branch/jump (control hazard)
    input  var logic        stall,      // hold contents (load-use hazard - added Step 3)
    input  var logic [31:0] pc_in,
    input  var logic [31:0] pc_plus4_in,
    input  var logic [31:0] instr_in,
    input  var logic        predicted_taken_in,   // front-end predicted this fetch taken
    input  var logic [31:0] predicted_target_in,  // ...to this target

    output var logic [31:0] pc_out,
    output var logic [31:0] pc_plus4_out,
    output var logic [31:0] instr_out,
    output var logic        valid_out,   // 0 = bubble (flushed slot) - used for instret counting
    output var logic        predicted_taken_out,
    output var logic [31:0] predicted_target_out
);
    always_ff @(posedge clk) begin
        if (rst || flush) begin
            pc_out               <= 32'd0;
            pc_plus4_out         <= 32'd0;
            instr_out            <= 32'd0;      // all-zero = illegal opcode -> control.sv default -> NOP-like (no writes)
            valid_out            <= 1'b0;
            predicted_taken_out  <= 1'b0;
            predicted_target_out <= 32'd0;
        end else if (!stall) begin
            pc_out               <= pc_in;
            pc_plus4_out         <= pc_plus4_in;
            instr_out            <= instr_in;
            valid_out            <= 1'b1;       // IF always produces a real fetched instruction
            predicted_taken_out  <= predicted_taken_in;
            predicted_target_out <= predicted_target_in;
        end
        // else: stall holds current values (do nothing)
    end
endmodule

`default_nettype wire