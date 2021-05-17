//
//  Heap Lab
//  Vriginia Tech
//
//  Generic struct rw
//
//  supports dirty and exclusive rw.
//
//  Yuqing Liu
//
`include "hacd_define.vh"
import hacd_pkg::*;
module hawk_struct_rw
#(
    parameter int STRUCT_WIDTH = 8,
    parameter int ADDR_WIDTH = 64 - STRUCT_WIDTH,
    parameter bit [63 : 0] ADDR_OFFSET = 0
)
(
    input  clk_i,
    input  rst_ni,
    input  wire  [ADDR_WIDTH - 1 : 0] r_addr_array,
    input  wire  [ADDR_WIDTH - 1 : 0] w_addr_array,
    input  wire  w_valid,
    input  wire  [STRUCT_WIDTH - 1 : 0] w_array,
    input  wire  r_valid,
    output logic [STRUCT_WIDTH - 1 : 0] r_array,
    output logic r_done,
    output logic w_done,
    output logic r_ready,
    output logic w_ready,

    //AXI packets
    output hacd_pkg::axi_rd_reqpkt_t rd_reqpkt,
    input  hacd_pkg::axi_rd_resppkt2_t rd_resppkt,

    //AXI packets
    output hacd_pkg::axi_wr_reqpkt_t wr_reqpkt,
    input  hacd_pkg::axi_wr_resppkt2_t wr_resppkt
);

parameter int STRUCT_SIZE = STRUCT_WIDTH / 8 + ((STRUCT_WIDTH % 8) ? 1 : 0);
parameter int cnt_per_cl = 512 / STRUCT_WIDTH;
wire [$clog2(cnt_per_cl) - 1 : 0] r_cacheline_index;
wire [$clog2(cnt_per_cl) - 1 : 0] w_cacheline_index;
assign r_cacheline_index = r_addr_array[$clog2(cnt_per_cl) - 1 : 0] >= cnt_per_cl ? cnt_per_cl - 1: r_addr_array[$clog2(cnt_per_cl) - 1 : 0];
assign w_cacheline_index = w_addr_array[$clog2(cnt_per_cl) - 1 : 0] >= cnt_per_cl ? cnt_per_cl - 1: w_addr_array[$clog2(cnt_per_cl) - 1 : 0];
assign rd_reqpkt.addr = {r_addr_array[ADDR_WIDTH - 1 : $clog2(cnt_per_cl)], {6{1'b0}}} + ADDR_OFFSET;
assign rd_reqpkt.arlen = 'd0;
assign wr_reqpkt.addr = {w_addr_array[ADDR_WIDTH - 1 : $clog2(cnt_per_cl)], {6{1'b0}}} + ADDR_OFFSET;
genvar i;
generate
    for(i = 0; i < cnt_per_cl; i++) begin
        assign wr_reqpkt.data[i * STRUCT_WIDTH + STRUCT_WIDTH - 1 : i * STRUCT_WIDTH] = w_array;
    end
endgenerate

typedef struct packed {
 	logic [cnt_per_cl - 1 : 0] [STRUCT_WIDTH - 1 : 0] a_p; 
} r_array_porting;
r_array_porting rp;
assign rp[`HACD_AXI4_DATA_WIDTH - 1 : 0] = rd_resppkt.rdata;

typedef struct packed {
 	logic [cnt_per_cl - 1 : 0] [STRUCT_SIZE - 1 : 0] a_p;
} w_array_porting;
w_array_porting wp;
assign wr_reqpkt.strb[63:0] = wp;

always_comb begin
    for (int j = 0; j < cnt_per_cl; j++)
        if (j == w_cacheline_index) begin
            wp.a_p[j] = {STRUCT_SIZE{1'b1}};
        end
        else
            wp.a_p[j] = 'd0;
end
//  All struct in memory are within a cacheline, so we good.

assign rd_reqpkt.rready = 1;

logic r_state, w_state;
assign r_ready = r_state;
assign w_ready = w_state;

logic r_done_clk, w_done_clk;
logic r_done_imm, w_done_imm;


initial begin
    rd_reqpkt.arvalid   <= 'd0;
    wr_reqpkt.awvalid   <= 'd0;
    wr_reqpkt.wvalid    <= 'd0;
    r_state             <= 'd1;
    w_state             <= 'd1;
    r_done              <= 'd0;
    w_done              <= 'd0;
end


always @(*) begin
    if (r_state) begin
        if (r_valid) begin
            rd_reqpkt.arvalid   <= 'd1;
            r_state             <= 'd0;
        end
    end
    else begin
        if (r_done_clk && !r_valid) begin
            r_done_imm  <= 'd0;
            r_state <= 'd1;
        end
    end
    if (r_done_clk && !r_done_imm && r_valid)
        r_done_imm <= 'd1;
end

always @(*) begin
    if (w_state) begin
        if (w_valid) begin
            wr_reqpkt.awvalid   <= 'd1;
            wr_reqpkt.wvalid    <= 'd1;
            w_state             <= 'd0;
        end
    end
    else begin
        if (w_done_clk && !w_valid) begin
            w_done_imm  <= 'd0;
            w_state <= 'd1;
        end
    end
    if (w_done_clk && !w_done_imm && w_valid)
        w_done_imm <= 'd1;
end

always @(posedge clk_i) begin
    if (rd_reqpkt.arvalid && rd_resppkt.arready) begin
        rd_reqpkt.arvalid <= 'd0;
        r_done_clk = 'd0;
    end
    if (wr_reqpkt.awvalid && wr_resppkt.awready) begin
        wr_reqpkt.awvalid <= 'd0;
        w_done_clk = 'd0;
    end
    if (wr_reqpkt.wvalid && wr_resppkt.wready)
        wr_reqpkt.wvalid <= 'd0;
    if (wr_resppkt.bvalid)
        if (wr_resppkt.bresp == 'd0)
            w_done_clk <= 'd1;
    if (rd_resppkt.rvalid && rd_resppkt.rlast)
        if(rd_resppkt.rresp =='d0) begin
            r_array <= rp.a_p[r_cacheline_index];
            r_done_clk <= 'd1;
        end
end

endmodule