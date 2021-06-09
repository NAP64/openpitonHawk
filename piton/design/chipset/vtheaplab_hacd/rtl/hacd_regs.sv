/////////////////////////////////////////////////////////////////////////////////
//
// Heap Lab @ CS @ Virginia Tech 
// 
// Author : Yuqing Liu
// Contact : nap64@vt.edu    
/////////////////////////////////////////////////////////////////////////////////

`include "hacd_define.vh"
import hacd_pkg::*;
module hacd_regs (
 
    input clk_i,  
    input rst_ni,

    input  wire  [63:0] hawk_cmd_reg,
    input  wire  hawk_cmd_flag_m,
    output reg   hawk_cmd_flag_s,

    output logic hawk_cmd_ready,
    input  wire  hawk_cmd_run,

    HACD_AXI_WR_BUS.mstr reg_axi_wr_bus,
    HACD_AXI_RD_BUS.mstr reg_axi_rd_bus,
    
    output reg dump_mem
);

hacd_pkg::axi_rd_reqpkt_t   r_reqpkt;
hacd_pkg::axi_rd_resppkt2_t r_resppkt;

hacd_pkg::axi_wr_reqpkt_t   w_reqpkt;
hacd_pkg::axi_wr_resppkt2_t w_resppkt;

localparam [7:0] //PPAGE is persudo-physical page
    MAP_PPAGE_TO_PART       ='d0,
    UNMAP_PPAGE             ='d1,
    SET_INCOMP_PPAGE        ='d2,
    MV_PPAGE_TO_PART        ='d3,
    MV_PAGE_BTWN_PART       ='d4,
    MERGE_PART              ='d5,
    SET_LOW_WTMK            ='d6,
    SET_HIGH_WTMK           ='d7,
    SWITCH_TO_STATIC        ='d8,
    SWITCH_TO_DYNAMIC       ='d9;
//Current NOT doing partitions.

`define FSM_WID 3
localparam [`FSM_WID - 1:0] //PPAGE is persudo-physical page
    IDLE          ='d0,
    ATT_LOOKUP    ='d1,
    TBL_UPDATE    ='d2,
    TBL_UPDATE1   ='d3,
    TBL_UPDATE2   ='d4,
    TBL_UPDATE3   ='d5;

reg   [`FSM_WID-1:0] state;
logic [`FSM_WID-1:0] state_n;
reg   [63:0] hawk_cmd_reg_ip;

AttEntry att_op;
logic [$clog2(ATT_ENTRY_MAX) - 1    : 0] att_r_addr_array;
logic [$clog2(ATT_ENTRY_MAX) - 1    : 0] att_w_addr_array;
logic att_w_valid, att_r_valid;
AttEntry att_read, att_write;
logic att_r_ready, att_w_ready;

ListEntry lst_op, lst_keep, lst_keep_n;
logic [$clog2(ATT_ENTRY_MAX) - 1    : 0] lst_r_addr_array;
logic [$clog2(ATT_ENTRY_MAX) - 1    : 0] lst_w_addr_array;
logic lst_w_valid, lst_r_valid;
ListEntry lst_read, lst_write;
logic lst_r_ready, lst_w_ready;

logic listen;
logic att_r_done_n, att_w_done_n, lst_r_done_n, lst_w_done_n;
reg   att_r_done, att_w_done, lst_r_done, lst_w_done;
reg   hawk_cmd_active;
assign att_r_done_n = att_r_ready & att_r_valid;
assign att_w_done_n = att_w_ready & att_w_valid;
assign lst_r_done_n = lst_r_ready & lst_r_valid;
assign lst_w_done_n = lst_w_ready & lst_w_valid;


always_comb begin
    lst_keep_n          = 'd0;
    listen              = 'd0;
    att_w_valid         = 'd0;
    att_r_valid         = 'd0;
    lst_w_valid         = 'd0;
    lst_r_valid         = 'd0;
    state_n             = state;
    hawk_cmd_ready      = 'd1;
    lst_write           = 'd0;
    att_write           = 'd0;
    att_r_addr_array    = 'd0;
    att_w_addr_array    = 'd0;
    lst_r_addr_array    = 'd0;
    lst_w_addr_array    = 'd0;
    case (state)
        IDLE: begin
            hawk_cmd_ready  = (hawk_cmd_flag_m != hawk_cmd_flag_s) | hawk_cmd_active;
            if (((hawk_cmd_flag_m != hawk_cmd_flag_s) | hawk_cmd_active) && hawk_cmd_run) begin
                case(hawk_cmd_active ? hawk_cmd_reg_ip[63:56] : hawk_cmd_reg[63:56])
                    MAP_PPAGE_TO_PART: begin
                        att_r_addr_array    = hawk_cmd_active ? hawk_cmd_reg_ip[$clog2(ATT_ENTRY_MAX) - 1    : 0] 
                                                : hawk_cmd_reg[$clog2(ATT_ENTRY_MAX) - 1    : 0];
                        att_r_valid         = !att_r_done;
                        listen              = att_r_done_n;
                        state_n             = ATT_LOOKUP;
                    end
                    UNMAP_PPAGE: begin
                        att_r_addr_array    = hawk_cmd_active ? hawk_cmd_reg_ip[$clog2(ATT_ENTRY_MAX) - 1    : 0] 
                                                : hawk_cmd_reg[$clog2(ATT_ENTRY_MAX) - 1    : 0];
                        att_r_valid         = !att_r_done;
                        listen              = att_r_done_n;
                        state_n             = ATT_LOOKUP;
                    end
                    default: begin
                        listen              = 'd1;
                        state_n             = IDLE;
                    end
                endcase
            end
        end
        ATT_LOOKUP: begin
            case (hawk_cmd_reg_ip[63:56])
                MAP_PPAGE_TO_PART: begin
                    state_n             = IDLE;
                    if (att_op.sts == STS_DALLOC && att_op.way == 'd1) begin
                        att_write.zpd_cnt   = att_op.zpd_cnt;
                        att_write.way       = 'd0;
                        att_write.sts       = STS_DALLOC;
                        listen              = (att_w_done_n | att_w_done);
                        att_w_valid         = !att_w_done;
                    end 
                    else
                        listen              = 'd1;
                end
                UNMAP_PPAGE: begin
                    if (att_op.sts != STS_DALLOC) begin
                        att_write.zpd_cnt   = att_op.zpd_cnt;
                        att_write.way       = 'd1;
                        att_write.sts       = STS_DALLOC;
                        att_w_addr_array    = hawk_cmd_reg[$clog2(ATT_ENTRY_MAX) - 1    : 0];
                        att_w_valid         = !att_w_done;
                        lst_r_valid         = !lst_r_done;
                        lst_r_addr_array    = att_op.way - (HAWK_PPA_START[63:12]);
                        listen              = (att_w_done_n | att_w_done) & (lst_r_done_n | lst_r_done);
                        state_n             = TBL_UPDATE;
                    end
                    else begin
                        listen              = 'd1;
                        state_n             = IDLE;
                    end
                end
            endcase
        end
        TBL_UPDATE: begin
            lst_w_valid             = !lst_w_done;
            lst_write.rsvd          = lst_op.rsvd;
            lst_write.way           = lst_op.way;
            lst_write.attEntryId    = 'd0;
            lst_write.next          = 'd0;
            lst_write.prev          = 'd0;
            lst_w_addr_array        = att_op.way - (HAWK_PPA_START[63:12]);//'hfff6300;
            lst_keep_n              = lst_op;
            listen                  = (lst_w_done_n | lst_w_done) & (lst_r_done_n | lst_r_done);
            if (lst_op.prev != 0) begin
                lst_r_valid         = !lst_r_done;
                lst_r_addr_array    = lst_op.prev - 1;// - 'hfff6300;
                state_n             = TBL_UPDATE1;
            end
            else if (lst_op.next != 0) begin
                lst_r_valid         = !lst_r_done;
                lst_r_addr_array    = lst_op.next - 1;// - 'hfff6300;
                state_n             = TBL_UPDATE2;
            end
            else begin
                state_n             = IDLE;
                listen              = (lst_w_done_n | lst_w_done);
            end     
        end
        TBL_UPDATE1: begin
            lst_keep_n              = lst_keep;
            lst_w_valid             = !lst_w_done;
            lst_write.rsvd          = lst_op.rsvd;
            lst_write.way           = lst_op.way;
            lst_write.attEntryId    = lst_op.attEntryId;
            lst_write.next          = lst_keep.next;
            lst_write.prev          = lst_op.prev;
            lst_w_addr_array        = lst_keep.prev - 1;//'hfff6300;
            if (lst_keep.next != 0) begin
                listen              = (lst_w_done_n | lst_w_done) & (lst_r_done_n | lst_r_done);
                lst_r_valid         = !lst_r_done;
                lst_r_addr_array    = lst_keep.next - 1;// - 'hfff6300;
                state_n             = TBL_UPDATE2;
            end
            else begin
                state_n             = IDLE;
                listen              = lst_w_ready;
            end
        end
        TBL_UPDATE2: begin
            lst_w_valid             = !lst_w_done;
            lst_write.rsvd          = lst_op.rsvd;
            lst_write.way           = lst_op.way;
            lst_write.attEntryId    = lst_op.attEntryId;
            lst_write.next          = lst_op.next;
            lst_write.prev          = lst_keep.prev;
            state_n                 = IDLE;
            listen                  = lst_w_ready;
            lst_w_addr_array        = lst_keep.next - 1;//'hfff6300;
        end
    endcase
end

//reg  [clogb2(LST_ENTRY_MAX)-1:0] low_wtmk, high_wtmk;
//reg hawk_enabled;

always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        //hawk_enabled        <= 'd1;
        //low_wtmk            <= 'd0;
        //high_wtmk           <= 'd0;
        att_op              <= 'd0;
        lst_op              <= 'd0;
        lst_keep            <= 'd0;
        state               <= IDLE;
        att_r_done          <= 'd0;
        att_w_done          <= 'd0;
        lst_r_done          <= 'd0;
        lst_w_done          <= 'd0;
        dump_mem            <= 'd0;
    end
    else begin
        //if ((hawk_cmd_flag_m != hawk_cmd_flag_s) && !hawk_cmd_active) begin
        //    case(hawk_cmd_reg[63:56])
        //        SET_LOW_WTMK:
        //            low_wtmk        <= hawk_cmd_reg[clogb2(LST_ENTRY_MAX)-1:0];
        //        SET_HIGH_WTMK:
        //            high_wtmk       <= hawk_cmd_reg[clogb2(LST_ENTRY_MAX)-1:0];
        //        SWITCH_TO_STATIC:
        //            hawk_enabled    <= 'd0;
        //        SWITCH_TO_DYNAMIC:
        //            hawk_enabled    <= 'd1;
        //    endcase
        //end
        if (state == IDLE && (hawk_cmd_flag_m != hawk_cmd_flag_s)) begin
            hawk_cmd_active     <= 'd1;
            hawk_cmd_flag_s     <= hawk_cmd_flag_m;
            hawk_cmd_reg_ip     <= hawk_cmd_reg;
        end
        if (state_n == IDLE && state != IDLE)
            hawk_cmd_active     <= 'd0;
        if (att_r_done_n)
            att_op <= att_read;
        if (lst_r_done_n)
            lst_op <= lst_read;
        if (listen) begin
            state               <= state_n;
            att_r_done          <= 'd0;
            att_w_done          <= 'd0;
            lst_r_done          <= 'd0;
            lst_w_done          <= 'd0;
            lst_keep            <= lst_keep_n;
        end
        else begin
            att_r_done          <= att_r_done_n | att_r_done;
            att_w_done          <= att_w_done_n | att_w_done;
            lst_r_done          <= lst_r_done_n | lst_r_done;
            lst_w_done          <= lst_w_done_n | lst_w_done;
        end
        if (att_w_done_n | lst_w_done_n)
            dump_mem <= 'd1;
        else
            dump_mem <= 'd0;
    end
end

assign reg_axi_rd_bus.axi_arid        = 6'd6;
assign reg_axi_rd_bus.axi_arsize      = `HACD_AXI4_BURST_SIZE;
assign reg_axi_rd_bus.axi_arburst     = `HACD_AXI4_BURST_TYPE;
assign reg_axi_rd_bus.axi_arlock      = 1'd0;
assign reg_axi_rd_bus.axi_arcache     = 4'd0;
assign reg_axi_rd_bus.axi_arprot      = 3'b010;
assign reg_axi_rd_bus.axi_arqos       = 4'd0;
assign reg_axi_rd_bus.axi_arregion    = 4'd0;
assign reg_axi_rd_bus.axi_aruser      = 11'd0;
assign reg_axi_rd_bus.axi_araddr      = r_reqpkt.addr;
assign reg_axi_rd_bus.axi_arlen       = r_reqpkt.arlen;
assign reg_axi_rd_bus.axi_arvalid     = r_reqpkt.arvalid;
assign reg_axi_rd_bus.axi_rready      = r_reqpkt.rready;
//assign reg_axi_rd_bus.axi_rid(),//in-order for now
//assign reg_axi_rd_bus.axi_ruser(), //not used for now
assign r_resppkt.rresp     =   reg_axi_rd_bus.axi_rresp;
assign r_resppkt.rdata     =   reg_axi_rd_bus.axi_rdata;
assign r_resppkt.rvalid    =   reg_axi_rd_bus.axi_rvalid;
assign r_resppkt.rlast     =   reg_axi_rd_bus.axi_rlast;
assign r_resppkt.arready   =   reg_axi_rd_bus.axi_arready;


assign reg_axi_wr_bus.axi_awid        = 'd6;
assign reg_axi_wr_bus.axi_wid         = 'd6;
assign reg_axi_wr_bus.axi_awlen       = 'd0;
assign reg_axi_wr_bus.axi_awsize      = `HACD_AXI4_BURST_SIZE;
assign reg_axi_wr_bus.axi_awburst     = `HACD_AXI4_BURST_TYPE;
assign reg_axi_wr_bus.axi_awlock      = 'd0;
assign reg_axi_wr_bus.axi_awcache     = 'd0;
assign reg_axi_wr_bus.axi_awprot      = 3'b010;
assign reg_axi_wr_bus.axi_awqos       = 'd0;
assign reg_axi_wr_bus.axi_awregion    = 'd0;
assign reg_axi_wr_bus.axi_awuser      = 'd0;
assign reg_axi_wr_bus.axi_wuser       = 'd0;
assign reg_axi_wr_bus.axi_wlast       = 'd1;
assign reg_axi_wr_bus.axi_bready      = 'd1;
assign reg_axi_wr_bus.axi_awaddr      = w_reqpkt.addr;
assign reg_axi_wr_bus.axi_wdata       = w_reqpkt.data;
assign reg_axi_wr_bus.axi_wstrb       = w_reqpkt.strb;
assign reg_axi_wr_bus.axi_awvalid     = w_reqpkt.awvalid;
assign reg_axi_wr_bus.axi_wvalid      = w_reqpkt.wvalid;
assign w_resppkt.awready   = reg_axi_wr_bus.axi_awready;
assign w_resppkt.wready    = reg_axi_wr_bus.axi_wready;
assign w_resppkt.bresp     = reg_axi_wr_bus.axi_bresp;
assign w_resppkt.bvalid    = reg_axi_wr_bus.axi_bvalid;

//hacd_pkg::axi_rd_reqpkt_t   r_reqpkt_null = 0'd0;
//hacd_pkg::axi_rd_resppkt2_t r_resppkt_null = 0'd0;
//hacd_pkg::axi_wr_reqpkt_t   w_reqpkt_null = 0'd0;
//hacd_pkg::axi_wr_resppkt2_t w_resppkt_null = 0'd0;

hacd_pkg::axi_rd_reqpkt_t   att_r_reqpkt;
hacd_pkg::axi_rd_resppkt2_t att_r_resppkt;
hacd_pkg::axi_wr_reqpkt_t   att_w_reqpkt;
hacd_pkg::axi_wr_resppkt2_t att_w_resppkt;

hacd_pkg::axi_rd_reqpkt_t   lst_r_reqpkt;
hacd_pkg::axi_rd_resppkt2_t lst_r_resppkt;
hacd_pkg::axi_wr_reqpkt_t   lst_w_reqpkt;
hacd_pkg::axi_wr_resppkt2_t lst_w_resppkt;

//assign r_reqpkt        = att_rd_reqpkt;
//assign w_reqpkt        = att_wr_reqpkt;
//assign att_rd_resppkt   = r_resppkt;
//assign att_wr_resppkt   = w_resppkt;
logic att_w_wait, att_w_wait2, att_r_wait;
logic lst_w_wait, lst_w_wait2, lst_r_wait;
hawk_struct_rw #(
    .STRUCT_WIDTH(  $bits(AttEntry)),
    .ADDR_WIDTH(    $clog2(ATT_ENTRY_MAX)),
    .ADDR_OFFSET(   HAWK_ATT_START)
)
u_att_rw
(
    .rst_ni,
    .clk_i,

    .r_ready        (   att_r_ready         ),
    .r_valid        (   att_r_valid         ),
    .ra_array       (   att_r_addr_array    ),
    .rd_array       (   att_read            ),
    .r_reqpkt       (   att_r_reqpkt        ),
    .r_resppkt      (   att_r_resppkt       ),
    .w_ready        (   att_w_ready         ),
    .w_valid        (   att_w_valid         ),
    .wa_array       (   att_w_addr_array    ),
    .wd_array       (   att_write           ),
    .w_reqpkt       (   att_w_reqpkt        ),
    .w_resppkt      (   att_w_resppkt       ),
    .w_wait         (att_w_wait),
    .w_wait2         (att_w_wait2),
    .r_wait         (att_r_wait)
);

hawk_struct_rw #(
    .STRUCT_WIDTH(  $bits(ListEntry)),
    .ADDR_WIDTH(    $clog2(LST_ENTRY_MAX)),
    .ADDR_OFFSET(   HAWK_LIST_START)
)
u_lst_rw
(
    .rst_ni,
    .clk_i,

    .r_ready        (   lst_r_ready         ),
    .r_valid        (   lst_r_valid         ),
    .ra_array       (   lst_r_addr_array    ),
    .rd_array       (   lst_read            ),
    .r_reqpkt       (   lst_r_reqpkt        ),
    .r_resppkt      (   lst_r_resppkt       ),
    .w_ready        (   lst_w_ready         ),
    .w_valid        (   lst_w_valid         ),
    .wa_array       (   lst_w_addr_array    ),
    .wd_array       (   lst_write           ),
    .w_reqpkt       (   lst_w_reqpkt        ),
    .w_resppkt      (   lst_w_resppkt       ),
    .w_wait         (lst_w_wait),
    .w_wait2         (lst_w_wait2),
    .r_wait         (lst_r_wait)
);

logic r_ps, w_ps;

hawk_arbiter #(
    .Breq($bits(hacd_pkg::axi_rd_reqpkt_t)),
    .Brsp($bits(hacd_pkg::axi_rd_resppkt2_t))
)
u_axt_rd_arbiter (
    .clk_i,
    .rst_ni,
    .input_array    ({  att_r_reqpkt,  lst_r_reqpkt   }),
    .input_valid    ({  att_r_valid,   lst_r_valid    }),
    .input_rsp      ({  att_r_resppkt, lst_r_resppkt  }),
    .output_ins     (   r_reqpkt   ),
    .output_rsp     (   r_resppkt  ),
    .output_done    (   att_r_ready | lst_r_ready ),
    .prev_served    (r_ps)
);

hawk_arbiter #(
    .Breq($bits(hacd_pkg::axi_wr_reqpkt_t)),
    .Brsp($bits(hacd_pkg::axi_wr_resppkt2_t))
)
u_axt_wr_arbiter (
    .clk_i,
    .rst_ni,
    .input_array    ({  att_w_reqpkt,   lst_w_reqpkt    }),
    .input_valid    ({  att_w_valid,    lst_w_valid     }),
    .input_rsp      ({  att_w_resppkt,  lst_w_resppkt   }),
    .output_ins     (   w_reqpkt   ),
    .output_rsp     (   w_resppkt  ),
    .output_done    (   att_w_ready | lst_w_ready ),
    .prev_served    (w_ps)
);

`ifdef HAWK_FPGA_DONE
ila_5 ila_hawk_reg_debug (
   .clk     (clk_i),
   .probe0  ({
        hawk_cmd_reg,
        //hawk_cmd_ready,
        //hawk_cmd_run,
 
        //state_n,
        state,
        att_op,
        lst_op,
        lst_keep,
        //lst_keep_n,
        //listen,
        
        //att_read,
        //att_r_valid,
        //att_r_ready,
        //att_r_addr_array [7:0],
        att_r_done,

        //att_write,
        //att_w_valid,
        //att_w_ready,
        //att_w_addr_array [7:0],
        att_w_done,

        //lst_read,
        //lst_r_valid,
        //lst_r_ready,
        //lst_r_addr_array [7:0],
        lst_r_done,

        //lst_write,
        //lst_w_valid,
        //lst_w_ready,
        //lst_w_addr_array [7:0],
        lst_w_done,

        reg_axi_wr_bus.axi_awvalid,
        reg_axi_wr_bus.axi_wvalid,
        reg_axi_wr_bus.axi_awready,
        reg_axi_wr_bus.axi_wready,
        reg_axi_rd_bus.axi_arvalid,
        reg_axi_rd_bus.axi_rvalid,
        reg_axi_rd_bus.axi_arready,
        reg_axi_rd_bus.axi_rready,

        //att_r_resppkt.arready,
        //att_r_resppkt.rvalid,
        //att_r_reqpkt.arvalid,
        //att_r_reqpkt.rready,
        //lst_r_resppkt.arready,
        //lst_r_resppkt.rvalid,
        //lst_r_reqpkt.arvalid,
        //lst_r_reqpkt.rready,

        //att_w_resppkt.awready,
        //att_w_resppkt.wready,
        //att_w_resppkt.bvalid,
        //att_w_reqpkt.awvalid,
        //att_w_reqpkt.wvalid,
        //lst_w_resppkt.awready,
        //lst_w_resppkt.wready,
        //lst_w_resppkt.bvalid,
        //lst_w_reqpkt.awvalid,
        //lst_w_reqpkt.wvalid,
        //{45{1'd0}}
        r_ps,
        w_ps,
        att_w_wait,
        att_w_wait2,
        att_r_wait,
        lst_w_wait,
        lst_w_wait2,
        lst_r_wait,
        dbg_rvalid,
        dbg_arready,
        615'd0
   })
);

`endif


endmodule
