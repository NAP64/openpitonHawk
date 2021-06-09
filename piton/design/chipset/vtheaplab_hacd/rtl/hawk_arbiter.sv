//
//  Heap Lab
//  Vriginia Tech
//
//  Generic round-robin arbiter
//
//  connects multiple service requester to one server
//
//  Yuqing Liu
//

module hawk_arbiter
#(
  parameter int Breq = 1,
  parameter int Brsp = 1,
  parameter int input_cnt = 2
) 
(
    input clk_i,
    input rst_ni,
    input wire  [input_cnt-1 : 0] [Breq - 1 : 0] input_array,
    input wire  [input_cnt-1 : 0] input_valid,
    output logic [input_cnt-1 : 0] [Brsp - 1 : 0] input_rsp,
    output logic [Breq - 1 : 0] output_ins,
    input wire  [Brsp - 1 : 0] output_rsp,
    input wire  output_done,

    output reg [$clog2(input_cnt)-1 : 0] prev_served
);

logic state, state_n;
logic [$clog2(input_cnt)-1 : 0] prev_served_n;

always_comb begin
    prev_served_n = prev_served;
    if (|input_valid[input_cnt-1 : 0] && !state) begin
        for (int i = 0; i < input_cnt; i++)
            if (input_valid[(i + prev_served) % input_cnt]) begin
                prev_served_n = ((i + prev_served) % input_cnt);
                break;
            end
    end
end

always_comb begin
    input_rsp    = 'd0;
    if (|input_valid[input_cnt-1 : 0] && !state) begin
        output_ins                  = input_array[prev_served_n];
        input_rsp[prev_served_n]    = output_rsp;
    end
    else begin
        output_ins                  = input_array[prev_served];
        input_rsp[prev_served]      = output_rsp;
    end
end

always_comb begin
    state_n = state;
    if (!state) begin
        if (|input_valid[input_cnt-1 : 0]) begin
            state_n = 'd1;
        end
    end
    else begin
        if (output_done) begin
            state_n = 'd0;
        end
    end
end

always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        state       <= 'd0;
        prev_served <= 'd0;
    end
    else begin
        prev_served <= prev_served_n;
        state <= state_n;
    end
end

endmodule