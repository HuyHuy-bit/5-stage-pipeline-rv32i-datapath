`default_nettype none

module hazard_detect (
    input  logic       mem_read_ex,   // instruction currently in EX is a load
    input  logic [4:0] rd_addr_ex,    // its destination register

    input  logic [4:0] rs1_addr_id,   // instruction currently in ID's operands
    input  logic [4:0] rs2_addr_id,

    output logic       stall          // 1 = insert one bubble
);
    always_comb begin
        stall = mem_read_ex &&
                (rd_addr_ex != 5'd0) &&
                ((rd_addr_ex == rs1_addr_id) || (rd_addr_ex == rs2_addr_id));
    end
endmodule

`default_nettype wire