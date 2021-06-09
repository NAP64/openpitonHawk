//
//  Heap Lab
//  Vriginia Tech
//
//  Generic struct rw
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

    output wire  r_ready,
    input  wire  r_valid,
    input  wire  [ADDR_WIDTH - 1 : 0]   ra_array,
    output wire  [STRUCT_WIDTH - 1 : 0] rd_array,
    output reg   r_error,

    output hacd_pkg::axi_rd_reqpkt_t    r_reqpkt,
    input  hacd_pkg::axi_rd_resppkt2_t  r_resppkt,

    output wire  w_ready,
    input  wire  w_valid,
    input  wire  [ADDR_WIDTH - 1 : 0]   wa_array,
    input  wire  [STRUCT_WIDTH - 1 : 0] wd_array,
    output reg   w_error,

    output hacd_pkg::axi_wr_reqpkt_t    w_reqpkt,
    input  hacd_pkg::axi_wr_resppkt2_t  w_resppkt,

    output reg w_wait, 
    output reg w_wait2, 
    output reg r_wait
);

parameter int STRUCT_SIZE = STRUCT_WIDTH / 8 + ((STRUCT_WIDTH % 8) ? 1 : 0);
parameter int cnt_per_cl = 512 / STRUCT_WIDTH;
wire [$clog2(cnt_per_cl) - 1 : 0] r_cacheline_index;
wire [$clog2(cnt_per_cl) - 1 : 0] w_cacheline_index;
assign r_cacheline_index = ra_array[$clog2(cnt_per_cl) - 1 : 0] >= cnt_per_cl ? cnt_per_cl - 1: ra_array[$clog2(cnt_per_cl) - 1 : 0];
assign w_cacheline_index = wa_array[$clog2(cnt_per_cl) - 1 : 0] >= cnt_per_cl ? cnt_per_cl - 1: wa_array[$clog2(cnt_per_cl) - 1 : 0];
assign r_reqpkt.addr = {ra_array[ADDR_WIDTH - 1 : $clog2(cnt_per_cl)], {6{1'b0}}} + ADDR_OFFSET;
assign r_reqpkt.arlen = 'd0;
assign w_reqpkt.addr = {wa_array[ADDR_WIDTH - 1 : $clog2(cnt_per_cl)], {6{1'b0}}} + ADDR_OFFSET;
genvar i;
generate
    for(i = 0; i < cnt_per_cl; i++) begin
        assign w_reqpkt.data[i * STRUCT_WIDTH + STRUCT_WIDTH - 1 : i * STRUCT_WIDTH] = wd_array;
    end
endgenerate

typedef struct packed {
 	logic [cnt_per_cl - 1 : 0] [STRUCT_WIDTH - 1 : 0] a_p; 
} rd_array_porting;
rd_array_porting rp;
assign rp[`HACD_AXI4_DATA_WIDTH - 1 : 0] = r_resppkt.rdata;
assign rd_array = rp.a_p[r_cacheline_index];

typedef struct packed {
 	logic [cnt_per_cl - 1 : 0] [STRUCT_SIZE - 1 : 0] a_p;
} wd_array_porting;
wd_array_porting wp;
assign w_reqpkt.strb[63:0] = wp;

always_comb begin
    for (int j = 0; j < cnt_per_cl; j++)
        if (j == w_cacheline_index)
            wp.a_p[j] = {STRUCT_SIZE{1'b1}};
        else
            wp.a_p[j] = 'd0;
end
//  All struct in memory are within a cacheline, so we good.

assign r_reqpkt.arvalid = r_valid & !r_wait;
assign r_reqpkt.rready  = r_valid;
assign r_ready = r_resppkt.rvalid; //fits so ok
assign w_reqpkt.awvalid = w_valid & !w_wait & !w_wait2;
assign w_reqpkt.wvalid  = w_valid & !w_wait2;
assign w_ready = w_resppkt.bvalid;//wready;

always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        w_wait  <= 'd0;
        w_wait2 <= 'd0;
        r_wait  <= 'd0;
        w_error <= 'd0;
        r_error <= 'd0; 
    end
    else begin
        if (w_resppkt.bvalid) begin
            w_wait  <= 'd0;
            w_wait2 <= 'd0;
        end
        else if (w_reqpkt.wvalid && w_resppkt.wready)
            w_wait2 <= 'd1;
        else if (w_reqpkt.awvalid && w_resppkt.awready)
            w_wait  <= 'd1;
        if (r_reqpkt.arvalid && r_resppkt.arready)
            r_wait  <= 'd1;
        else if (r_reqpkt.rready && r_resppkt.rvalid)
            r_wait  <= 'd0;
        if (w_resppkt.bvalid && w_resppkt.bresp != 'd0)
            w_error <= 'd1;
        if (r_resppkt.rvalid && r_resppkt.rresp != 'd0)
            r_error <= 'd1;
    end
end

endmodule