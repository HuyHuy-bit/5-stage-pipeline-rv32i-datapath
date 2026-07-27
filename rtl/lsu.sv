// lsu.sv - subword load/store handling.
//
// The boundary between two vocabularies. Above it: RISC-V lb/lh/lw/lbu/lhu and
// sb/sh/sw, with sign extension and unaligned-within-a-word offsets. Below it:
// whole words plus a 4-bit byte enable, which is all a memory or a cache needs
// to understand.
//
// This used to live inside data_mem, which was fine while data_mem was the only
// thing loads and stores could reach. A cache in front of it would have needed
// its own copy of exactly this logic, so it moved out here instead.
`default_nettype none

import rv32i_pkg::*;

module lsu (
    input  var logic [2:0]  funct3,       // access size + signedness
    input  var logic [1:0]  byte_off,     // addr[1:0]
    input  var logic        mem_write,
    input  var logic        mem_read,
    input  var logic [31:0] store_data,   // rs2, not yet shifted into its lane
    input  var logic [31:0] mem_word,     // word coming back from cache/memory

    output var logic [3:0]  byte_en,      // which lanes a store touches
    output var logic [31:0] store_word,   // store_data shifted into its lane
    output var logic [31:0] load_data     // extracted and extended
);
    // funct3 size encodings (F3_LB/F3_LH/F3_LW/F3_LBU/F3_LHU) live in
    // rv32i_pkg.sv now — was a local copy, same duplication problem the
    // package exists to solve.

    // STORE: byte-enable generation.
    // byte_en[i] = 1 means lane i (bits [8i+7 : 8i]) gets written.
    always_comb begin
        byte_en = 4'b0000;
        if (mem_write) begin
            case (funct3)
                F3_LB:   byte_en = 4'b0001 << byte_off;   // sb: one lane
                F3_LH:   byte_en = 4'b0011 << byte_off;   // sh: two lanes (off = 0 or 2)
                F3_LW:   byte_en = 4'b1111;               // sw: all four
                default: byte_en = 4'b0000;
            endcase
        end
    end

    // Align the store value so its low byte/half lands in the addressed lane.
    assign store_word = store_data << (8 * byte_off);

    // LOAD: extract the addressed lane and extend.
    logic [7:0]  sel_byte;
    logic [15:0] sel_half;
    assign sel_byte = mem_word[8*byte_off +: 8];    // byte at byte_off
    assign sel_half = byte_off[1] ? mem_word[31:16] // half at off 2
                                  : mem_word[15:0]; // half at off 0

    always_comb begin
        if (mem_read) begin
            case (funct3)
                F3_LB:   load_data = {{24{sel_byte[7]}},  sel_byte};  // lb  (sign-ext)
                F3_LH:   load_data = {{16{sel_half[15]}}, sel_half};  // lh  (sign-ext)
                F3_LW:   load_data = mem_word;                        // lw
                F3_LBU:  load_data = {24'b0, sel_byte};               // lbu (zero-ext)
                F3_LHU:  load_data = {16'b0, sel_half};               // lhu (zero-ext)
                default: load_data = mem_word;
            endcase
        end else begin
            load_data = 32'd0;
        end
    end
endmodule

`default_nettype wire
