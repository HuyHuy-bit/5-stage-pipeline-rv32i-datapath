`default_nettype none

module data_mem (
    input  logic        clk,          // clock
    input  logic        mem_write,    // 1 when storing
    input  logic        mem_read,     // 1 when loading
    input  logic [2:0]  funct3,       // access size + signedness (from instruction)
    input  logic [31:0] addr,         // byte address (ALU result)
    input  logic [31:0] write_data,   // value to store (rs2)
    output logic [31:0] read_data     // value loaded (already extended)
);
    // Word-addressed array; subword access handled via per-byte write strobes.
    logic [31:0] mem_array [0:1023];

    // funct3 size encodings (low 2 bits = width; bit2 = unsigned for loads)
    localparam [2:0] F3_B  = 3'b000; // lb  / sb
    localparam [2:0] F3_H  = 3'b001; // lh  / sh
    localparam [2:0] F3_W  = 3'b010; // lw  / sw
    localparam [2:0] F3_BU = 3'b100; // lbu
    localparam [2:0] F3_HU = 3'b101; // lhu

    logic [9:0]  word_idx;
    logic [1:0]  byte_off;
    assign word_idx = addr[11:2];   // which 32-bit word
    assign byte_off = addr[1:0];    // which byte within the word

    // STORE: byte-enable generation
    // byte_en[i] = 1 means lane i (bits [8i+7 : 8i]) gets written this cycle.
    logic [3:0] byte_en;
    always_comb begin
        byte_en = 4'b0000;
        if (mem_write) begin
            case (funct3)
                F3_B:    byte_en = 4'b0001 << byte_off;        // sb: one lane
                F3_H:    byte_en = 4'b0011 << byte_off;        // sh: two lanes (off = 0 or 2)
                F3_W:    byte_en = 4'b1111;                    // sw: all four
                default: byte_en = 4'b0000;
            endcase
        end
    end

    // Align the store value so its low byte/half lands in the addressed lane.
    logic [31:0] store_aligned;
    assign store_aligned = write_data << (8 * byte_off);

    // Per-lane independent write (this is the "byte-enable array" behavior).
    always_ff @(posedge clk) begin
        if (byte_en[0]) mem_array[word_idx][7:0]   <= store_aligned[7:0];
        if (byte_en[1]) mem_array[word_idx][15:8]  <= store_aligned[15:8];
        if (byte_en[2]) mem_array[word_idx][23:16] <= store_aligned[23:16];
        if (byte_en[3]) mem_array[word_idx][31:24] <= store_aligned[31:24];
    end

    //LOAD: extract addressed lane + extend
    logic [31:0] word_rd;
    logic [7:0]  sel_byte;
    logic [15:0] sel_half;
    assign word_rd  = mem_array[word_idx];
    assign sel_byte = word_rd[8*byte_off +: 8];     // byte at byte_off
    assign sel_half = byte_off[1] ? word_rd[31:16]  // half at off 2
                                  : word_rd[15:0];  // half at off 0

    always_comb begin
        if (mem_read) begin
            case (funct3)
                F3_B:    read_data = {{24{sel_byte[7]}},  sel_byte};  // lb  (sign-ext)
                F3_H:    read_data = {{16{sel_half[15]}}, sel_half};  // lh  (sign-ext)
                F3_W:    read_data = word_rd;                         // lw
                F3_BU:   read_data = {24'b0, sel_byte};               // lbu (zero-ext)
                F3_HU:   read_data = {16'b0, sel_half};               // lhu (zero-ext)
                default: read_data = word_rd;
            endcase
        end else begin
            read_data = 32'd0;
        end
    end
endmodule

`default_nettype wire