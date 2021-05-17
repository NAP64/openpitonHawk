/////////////////////////////////////////////////////////////////////////////////
//
// Heap Lab Research
// Block: Hardware Accelerated Compressor Decompressor
// 
// Author : Raghavendra Srinivas
// Contact : raghavs@vt.edu    
/////////////////////////////////////////////////////////////////////////////////

module hacd_regs (
 
    input clk_i,  
    input rst_ni,
    // Bus Interface
    input  hacd_pkg::reg_intf_req_a32_d32 req_i,
    output hacd_pkg::reg_intf_resp_d32    resp_o,

    output logic hawk_cmd_ready,
    input  wire  hawk_cmd_run,

    HACD_AXI_WR_BUS.mstr reg_axi_wr_bus, 
    HACD_AXI_RD_BUS.mstr reg_axi_rd_bus,
    
    output reg use_axi,
    output reg dump_mem
);
reg dump_mem_n;
hacd_pkg::axi_rd_reqpkt_t   rd_reqpkt;
hacd_pkg::axi_rd_resppkt2_t rd_resppkt;

hacd_pkg::axi_wr_reqpkt_t   wr_reqpkt;
hacd_pkg::axi_wr_resppkt2_t wr_resppkt;

//hacd_pkg::tol_updpkt_t n_tol_updpkt;
//hacd_pkg::att_lkup_reqpkt_t n_lkup_reqpkt;

logic [63:0] hacd_p;
logic [63:0] hacd_n;
logic reg_update, reg_update_n;
logic [7:0] ctrl;
//assign ctrl = hacd_p[63:56];
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
//Should be handles in a higher level 
//that identifies partitions and handles page transfer and static/dynamic.

logic use_axi_n;
logic first_read;

always@* begin
    resp_o.ready = 1'b1;
    resp_o.rdata = '0;
    resp_o.error = '0;
    //regs enables
    reg_update_n = reg_update;
    if (req_i.valid) begin
        if (req_i.write) begin
            unique case(req_i.addr)
                32'h0: begin //Always update both for a full command
                    hacd_n[31:0] = req_i.wdata[31:0];
                end
                32'h4: begin
                    hacd_n[63:32] = req_i.wdata[31:0];
                    reg_update_n = 1'b1;
                end
                default: 
                    resp_o.error = 1'b1;
            endcase
        end else begin
            unique case(req_i.addr)
                32'h0: begin
                    resp_o.rdata[31:0] = hacd_p[31:0];
                end
                32'h4: begin
                    resp_o.rdata[31:0] = hacd_p[63:32];
                end
                default: 
                    resp_o.error = 1'b1;
            endcase
        end //write
    end //valid
    //if (post_read && !first_read) begin
    //    first_read = 1;
    //    reg_update_n = 1'b1;
    //    hacd_n = 64'h0x0100000000000005;
    //end
end //always_comb

`define FSM_WID 5
localparam [`FSM_WID - 1:0] //PPAGE is persudo-physical page
    IDLE          ='d0,
    ATT_LOOKUP0    ='d6,
    ATT_LOOKUP    ='d1,
    TBL_UPDATE    ='d2,
    TBL_UPDATE1   ='d3,
    TBL_UPDATE2   ='d4,
    TBL_UPDATE3   ='d5;

reg [`FSM_WID-1:0] p_state, n_state;

AttEntry att_op;
logic [$clog2(ATT_ENTRY_MAX) - 1    : 0] att_r_addr_array;
logic [$clog2(ATT_ENTRY_MAX) - 1    : 0] att_w_addr_array;
logic att_w_valid, att_r_valid;
AttEntry att_read, att_write;
wire att_r_done, att_w_done, att_r_ready, att_w_ready;

ListEntry lst_op;
logic [$clog2(ATT_ENTRY_MAX) - 1    : 0] lst_r_addr_array;
logic [$clog2(ATT_ENTRY_MAX) - 1    : 0] lst_w_addr_array;
logic lst_w_valid, lst_r_valid;
ListEntry lst_read, lst_write;
wire lst_r_done, lst_w_done, lst_r_ready, lst_w_ready;

//always @(posedge clk_i) begin
//    if (reg_update && hawk_cmd_run) begin
//        case(ctrl)
//            MAP_PPAGE_TO_PART: begin
//                
//            end
//            UNMAP_PPAGE: begin
//                //if (p_state == IDLE) begin
//                //    n_state             = ATT_LOOKUP0;
//                //    p_state             = ATT_LOOKUP0;
//                //    att_r_addr_array    = hacd_p[$clog2(ATT_ENTRY_MAX) - 1    : 0];
//                //    
//                //end
//            end
//            SET_LOW_WTMK: begin
//                reg_update      = 'd0;
//                low_wtmk        = hacd_p[clogb2(LST_ENTRY_MAX)-1:0]; // use low parts
//                hawk_cmd_ready  = 'd0;
//            end
//            SWITCH_TO_STATIC: begin
//                reg_update      = 'd0;
//                hawk_enabled    = '0;
//                hawk_cmd_ready  = 'd0;
//            end
//            SWITCH_TO_DYNAMIC: begin
//                reg_update      = 'd0;
//                hawk_enabled    = '1;
//                hawk_cmd_ready  = 'd0;
//            end
//        endcase
//    end
//end

always @* begin
    use_axi_n <= att_w_valid|att_r_valid|lst_w_valid|lst_r_valid;
    use_axi <= use_axi_n;
    if (reg_update_n)
        hawk_cmd_ready <= 'd1;
    case (p_state)
        IDLE: begin
            if (reg_update_n && hawk_cmd_run) begin
                hacd_p = hacd_n;
                //ctrl = hacd_p[63:56];
                case(hacd_n[63:56])
                    UNMAP_PPAGE: begin
                        n_state             <= ATT_LOOKUP0;
                        p_state             <= ATT_LOOKUP0;
                        att_r_addr_array    <= hacd_p[$clog2(ATT_ENTRY_MAX) - 1    : 0];
                        reg_update          <= 'd1;
                    end
                    SET_LOW_WTMK: begin
                        reg_update      <= 'd0;
                        //low_wtmk        <= hacd_n[clogb2(LST_ENTRY_MAX)-1:0]; // use low parts
                        hawk_cmd_ready  <= 'd0;
                    end
                    SWITCH_TO_STATIC: begin
                        reg_update      <= 'd0;
                        //hawk_enabled    <= '0;
                        hawk_cmd_ready  <= 'd0;
                    end
                    SWITCH_TO_DYNAMIC: begin
                        reg_update      <= 'd0;
                        //hawk_enabled    <= '1;
                        hawk_cmd_ready  <= 'd0;
                    end
                    default: begin
                        reg_update      <= 'd0;
                        hawk_cmd_ready  <= 'd0;
                    end
                endcase
            end
        end
        ATT_LOOKUP0: begin
            if (att_r_ready) begin
                n_state <= ATT_LOOKUP;
                att_r_valid <= 1;
            end
            if (n_state == ATT_LOOKUP && !att_r_ready)
                p_state         <= ATT_LOOKUP;
        end
        ATT_LOOKUP: begin
            if (att_r_ready) begin
                att_op      <= att_read;
                if (att_read.sts != STS_DALLOC) begin
                    att_write.way       <= 'd1;
                    att_write.sts       <= STS_DALLOC;
                    att_w_addr_array    <= att_r_addr_array;
                    p_state             <= TBL_UPDATE;
                    n_state             <= TBL_UPDATE;
                end
                else begin
                    p_state         <= IDLE;
                    n_state         <= IDLE;
                    hawk_cmd_ready  <= 'd0;
                end
            end
        end
        TBL_UPDATE: begin
            if (att_w_ready && lst_r_ready) begin
                att_w_valid         <= 'd1;
                lst_r_valid         <= 'd1;
                lst_r_addr_array    <= att_op.way - (HAWK_PPA_START[63:12]);//'hfff6300;
                n_state             <= TBL_UPDATE1;
            end
            else if (n_state == TBL_UPDATE1 && !lst_r_ready)
                p_state         <= TBL_UPDATE1;
        end
        TBL_UPDATE1: begin
            if (lst_r_ready && lst_w_ready) begin
                lst_op                  <= lst_read;
                lst_w_valid             <= 'd1;
                lst_write.way           <= lst_read.way;
                lst_write.attEntryId    <= 'd0;
                lst_write.next          <= 'd0;
                lst_write.prev          <= 'd0;
                lst_r_valid             <= 'd1;
                lst_w_addr_array        <= att_op.way - (HAWK_PPA_START[63:12]);//'hfff6300;
                lst_r_addr_array        <= lst_read.prev - 1;// - 'hfff6300;
                n_state                 <= TBL_UPDATE2;
            end
            else if (n_state == TBL_UPDATE2 && !lst_r_ready)
                p_state         <= TBL_UPDATE2;
        end
        TBL_UPDATE2: begin
            if (lst_r_ready && lst_w_ready) begin
                lst_w_valid             <= 'd1;
                lst_write.way           <= lst_read.way;
                lst_write.attEntryId    <= lst_read.attEntryId;
                lst_write.next          <= lst_op.next;
                lst_write.prev          <= lst_read.prev;
                lst_r_valid             <= 'd1;
                lst_w_addr_array        <= lst_op.prev - 1;
                lst_r_addr_array        <= lst_op.next - 1;// - 'hfff6300;
                n_state                 <= TBL_UPDATE3;
            end
            else if (n_state == TBL_UPDATE3 && !lst_r_ready)
                p_state         <= TBL_UPDATE3;
        end
        TBL_UPDATE3: begin
            if (lst_r_ready && lst_w_ready) begin
                lst_w_valid             <= 'd1;
                lst_w_addr_array        <= lst_r_addr_array;
                lst_write.way           <= lst_read.way;
                lst_write.attEntryId    <= lst_read.attEntryId;
                lst_write.next          <= lst_read.next;
                lst_write.prev          <= lst_op.prev;
                hawk_cmd_ready          <= 'd0;
                p_state                 <= IDLE;
                n_state                 <= IDLE;
            end
        end
    endcase
    if (att_w_valid && att_w_done) begin
        att_w_valid <= 'd0;
        dump_mem_n <= 1;
    end
    else if (lst_w_valid && lst_w_done) begin
        lst_w_valid <= 'd0;
        dump_mem_n <= 1;
    end
    else if (dump_mem)
        dump_mem_n <= 0;
    if (att_r_valid && att_r_done) begin
        att_r_valid <= 'd0;
    end
    if (lst_r_valid && lst_r_done) begin
        lst_r_valid <= 'd0;
    end
end

always @(posedge clk_i) begin
    if (dump_mem_n)
        dump_mem <= 1;
    else
        dump_mem <= 0;
end

//always @(negedge rst_ni) 
initial begin 
    hacd_n <= '0;
    hacd_p <= '0;
    //hawk_enabled <= '1;
    att_op <= 'd0;
    att_w_valid <= '0;
    att_r_valid <= '0;
    att_write <= 'd0;
    lst_op <= 'd0;
    lst_r_addr_array <= 'd0;
    lst_w_addr_array <= 'd0;
    att_r_addr_array <= 'd0;
    att_w_addr_array <= 'd0;
    lst_w_valid <= '0;
    lst_r_valid <= '0;
    lst_write <= 'd0;
    hawk_cmd_ready <= 'd0;
    n_state <= IDLE;
    p_state <= IDLE;
    use_axi <= 0;
    use_axi_n <= 0;
    first_read <= 0;
end

assign reg_axi_rd_bus.axi_arid        = 6'd1;
assign reg_axi_rd_bus.axi_arsize      = `HACD_AXI4_BURST_SIZE;
assign reg_axi_rd_bus.axi_arburst     = `HACD_AXI4_BURST_TYPE;
assign reg_axi_rd_bus.axi_arlock      = 1'd0;
assign reg_axi_rd_bus.axi_arcache     = 4'd0;
assign reg_axi_rd_bus.axi_arprot      = 3'b010;
assign reg_axi_rd_bus.axi_arqos       = 4'd0;
assign reg_axi_rd_bus.axi_arregion    = 4'd0;
assign reg_axi_rd_bus.axi_aruser      = 11'd0;
assign reg_axi_rd_bus.axi_araddr      = rd_reqpkt.addr;
assign reg_axi_rd_bus.axi_arlen       = rd_reqpkt.arlen;
assign reg_axi_rd_bus.axi_arvalid     = rd_reqpkt.arvalid;
assign reg_axi_rd_bus.axi_rready      = rd_reqpkt.rready;
//assign reg_axi_rd_bus.axi_rid(),//in-order for now
//assign reg_axi_rd_bus.axi_ruser(), //not used for now
assign rd_resppkt.rresp     =   reg_axi_rd_bus.axi_rresp;
assign rd_resppkt.rdata     =   reg_axi_rd_bus.axi_rdata;
assign rd_resppkt.rvalid    =   reg_axi_rd_bus.axi_rvalid;
assign rd_resppkt.rlast     =   reg_axi_rd_bus.axi_rlast;
assign rd_resppkt.arready   =   reg_axi_rd_bus.axi_arready;


assign reg_axi_wr_bus.axi_awid        = 'd1;
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
assign reg_axi_wr_bus.axi_awaddr      = wr_reqpkt.addr;
assign reg_axi_wr_bus.axi_wdata       = wr_reqpkt.data;
assign reg_axi_wr_bus.axi_wstrb       = wr_reqpkt.strb;
assign reg_axi_wr_bus.axi_awvalid     = wr_reqpkt.awvalid;
assign reg_axi_wr_bus.axi_wvalid      = wr_reqpkt.wvalid;
assign wr_resppkt.awready   = reg_axi_wr_bus.axi_awready;
assign wr_resppkt.wready    = reg_axi_wr_bus.axi_wready;
assign wr_resppkt.bresp     = reg_axi_wr_bus.axi_bresp;
assign wr_resppkt.bvalid    = reg_axi_wr_bus.axi_bvalid;

//hacd_pkg::axi_rd_reqpkt_t   rd_reqpkt_null = 0'd0;
//hacd_pkg::axi_rd_resppkt2_t rd_resppkt_null = 0'd0;
//hacd_pkg::axi_wr_reqpkt_t   wr_reqpkt_null = 0'd0;
//hacd_pkg::axi_wr_resppkt2_t wr_resppkt_null = 0'd0;

hacd_pkg::axi_rd_reqpkt_t   att_rd_reqpkt;
hacd_pkg::axi_rd_resppkt2_t att_rd_resppkt;
hacd_pkg::axi_wr_reqpkt_t   att_wr_reqpkt;
hacd_pkg::axi_wr_resppkt2_t att_wr_resppkt;

hacd_pkg::axi_rd_reqpkt_t   lst_rd_reqpkt;
hacd_pkg::axi_rd_resppkt2_t lst_rd_resppkt;
hacd_pkg::axi_wr_reqpkt_t   lst_wr_reqpkt;
hacd_pkg::axi_wr_resppkt2_t lst_wr_resppkt;

//assign rd_reqpkt        = att_rd_reqpkt;
//assign wr_reqpkt        = att_wr_reqpkt;
//assign att_rd_resppkt   = rd_resppkt;
//assign att_wr_resppkt   = wr_resppkt;
//assign use_axi = att_w_valid|att_r_valid|lst_w_valid|lst_r_valid;

hawk_struct_rw #(
    .STRUCT_WIDTH(  $bits(AttEntry)),
    .ADDR_WIDTH(    $clog2(ATT_ENTRY_MAX)),
    .ADDR_OFFSET(   HAWK_ATT_START)
)
u_att_rw
(
    .rst_ni,
    .clk_i,

    .r_addr_array   (   att_r_addr_array    ),
    .w_addr_array   (   att_w_addr_array    ),
    .w_valid        (   att_w_valid         ),
    .r_valid        (   att_r_valid         ),
    .w_array        (   att_write           ),
    .r_array        (   att_read            ),
    .r_done         (   att_r_done          ),
    .w_done         (   att_w_done          ),
    .r_ready        (   att_r_ready         ),
    .w_ready        (   att_w_ready         ),
    .rd_reqpkt      (   att_rd_reqpkt       ),
    .rd_resppkt     (   att_rd_resppkt      ),
    .wr_reqpkt      (   att_wr_reqpkt       ),
    .wr_resppkt     (   att_wr_resppkt      )
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

    .r_addr_array   (   lst_r_addr_array    ),
    .w_addr_array   (   lst_w_addr_array    ),
    .w_valid        (   lst_w_valid         ),
    .r_valid        (   lst_r_valid         ),
    .w_array        (   lst_write           ),
    .r_array        (   lst_read            ),
    .r_done         (   lst_r_done          ),
    .w_done         (   lst_w_done          ),
    .r_ready        (   lst_r_ready         ),
    .w_ready        (   lst_w_ready         ),
    .rd_reqpkt      (   lst_rd_reqpkt       ),
    .rd_resppkt     (   lst_rd_resppkt      ),
    .wr_reqpkt      (   lst_wr_reqpkt       ),
    .wr_resppkt     (   lst_wr_resppkt      )
);

hawk_arbiter #(
    .Breq($bits(hacd_pkg::axi_rd_reqpkt_t)),
    .Brsp($bits(hacd_pkg::axi_rd_resppkt2_t))
)
u_axt_rd_arbiter (
    .clk_i,
    .rst_ni,
    .input_array    ({  att_rd_reqpkt,  lst_rd_reqpkt   }),
    .input_valid    ({  att_r_valid,    lst_r_valid     }),
    .input_rsp      ({  att_rd_resppkt, lst_rd_resppkt  }),
    .output_ins     (   rd_reqpkt   ),
    .output_rsp     (   rd_resppkt  ),
    .output_done    (   att_r_done | lst_r_done )
);

hawk_arbiter #(
    .Breq($bits(hacd_pkg::axi_wr_reqpkt_t)),
    .Brsp($bits(hacd_pkg::axi_wr_resppkt2_t))
)
u_axt_wr_arbiter (
    .clk_i,
    .rst_ni,
    .input_array    ({  att_wr_reqpkt,  lst_wr_reqpkt   }),
    .input_valid    ({  att_w_valid,    lst_w_valid     }),
    .input_rsp      ({  att_wr_resppkt, lst_wr_resppkt  }),
    .output_ins     (   wr_reqpkt   ),
    .output_rsp     (   wr_resppkt  ),
    .output_done    (   att_w_done | lst_w_done )
);

`ifdef HAWK_FPGA
ila_4 ila_hawk_ain1_debug (
   .clk         (clk_i                                  ),
   .probe0      (rst_ni                                 ),
   .probe1      (wr_resppkt.awready                     ),
   .probe2      (wr_resppkt.wready                      ),
   .probe3      (wr_resppkt.bvalid                      ),
   .probe4      (wr_reqpkt.awvalid                      ),
   .probe5      (wr_reqpkt.wvalid                       ),
   .probe6      (rd_resppkt.arready                     ),
   .probe7      (rd_resppkt.rvalid                      ),
   .probe8      (rd_reqpkt.arvalid                      ),
   .probe9      (rd_reqpkt.rready                       ),
   .probe10     (use_axi                                ),
   .probe11     (use_axi_n                              ),
   .probe12     (reg_update                             ),
   .probe13     (reg_update_n                           ),
   .probe14     (att_w_valid                            ),
   .probe15     (att_w_ready                            ),
   .probe18     (att_w_done                             ),
   .probe21     (att_r_valid                            ),
   .probe23     (att_r_ready                            ),
   .probe24     (att_r_done                             ),
   .probe17     (wr_reqpkt.addr[35:0]                   ),
   .probe27     (rd_reqpkt.addr[35:0]                   ),
   .probe19     (p_state                                ),
   .probe22     (n_state                                ),
   .probe20     ({hacd_n, hacd_p, req_i.addr, req_i.wdata, {256{1'd0}}}    ),
   .probe16     ('d0                                    ),
   .probe25     ('d0                                    ),
   .probe26     ('d0                                    ),
   .probe28     ( req_i.valid                                 ),
   .probe29     ('d0                                    ),
   .probe30     ('d0                                    ),
   .probe31     (req_i.write                                  ),
   .probe32     ('d0                                    ),
   .probe33     ('d0                                    ),
   .probe34     ('d0                                    ),
   .probe35     ('d0                                    ),
   .probe36     ('d0                                    ),
   .probe37     ('d0                                    ),
   .probe38     ('d0                                    ),
   .probe39     ('d0                                    ),
   .probe40     ('d0                                    ),
   .probe41     ('d0                                    ),
   .probe42     ('d0                                    ),
   .probe43     ('d0                                    ),
   .probe44     ('d0                                    ),
   .probe45     ('d0                                    ),
   .probe46     ('d0                                    ),
   .probe47     ('d0                                    ),
   .probe48     ('d0                                    ),
   .probe49     ('d0                                    ),
   .probe50     ('d0                                    ),
   .probe51     ('d0                                    ),
   .probe52     ('d0                                    ),
   .probe53     ('d0                                    ),
   .probe54     ('d0                                    ),
   .probe55     ('d0                                    ),
   .probe56     ('d0                                    ),
   .probe57     ('d0                                    ),
   .probe58     ('d0                                    ),
   .probe59     ('d0                                    ),
   .probe60     ('d0                                    ),
   .probe61     ('d0                                    ),
   .probe62     ('d0                                    ),
   .probe63     ('d0                                    )

);

`endif


endmodule
