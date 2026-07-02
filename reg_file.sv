module reg_file (
    input  logic        clk,
    input  logic        rst,
    input  logic [4:0]  rs1_addr,     // source register 1 number
    input  logic [4:0]  rs2_addr,     // source register 2 number
    input  logic [4:0]  rd_addr,      // destination register number
    input  logic [31:0] rd_data,      // data to write to rd
    input  logic        rd_write_en,  // write enable
    output logic [31:0] rs1_data,     // value read from rs1
    output logic [31:0] rs2_data,     // value read from rs2
    output logic [31:0] dbg_x1,       // debug read-out of x1..x5
    output logic [31:0] dbg_x2,
    output logic [31:0] dbg_x3,
    output logic [31:0] dbg_x4,
    output logic [31:0] dbg_x5
);
    logic [31:0] reg_array [0:31];

    // Read-during-write bypass: if WB is writing rd this exact cycle and ID
    // is reading that same register this exact cycle, forward the incoming
    // write data instead of the (stale, about-to-be-overwritten) array value.
    // Without this, an instruction whose producer is exactly 3 instructions
    // earlier reads garbage - the write and the read race on the same edge,
    // and combinational read-before-write loses that race.
    assign rs1_data = (rs1_addr == 5'd0) ? 32'd0
                     : (rd_write_en && rd_addr != 5'd0 && rd_addr == rs1_addr) ? rd_data
                     : reg_array[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? 32'd0
                     : (rd_write_en && rd_addr != 5'd0 && rd_addr == rs2_addr) ? rd_data
                     : reg_array[rs2_addr];

    // Debug taps exposed as proper ports (instead of hierarchical reach-in).
    assign dbg_x1 = reg_array[1];
    assign dbg_x2 = reg_array[2];
    assign dbg_x3 = reg_array[3];
    assign dbg_x4 = reg_array[4];
    assign dbg_x5 = reg_array[5];

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 32; i++) begin
                reg_array[i] <= 32'd0;
            end
        end else if (rd_write_en && rd_addr != 5'd0) begin
            reg_array[rd_addr] <= rd_data;
        end
    end
endmodule