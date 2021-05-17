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
    input wire  output_done
);

logic p_state, n_state;
logic [$clog2(input_cnt)-1 : 0] prev_served;

initial begin
    p_state <= 'd0;
    n_state <= 'd0;
    prev_served <= 'd0;
end

always @(posedge clk_i) begin
    p_state <= n_state;
end

always_comb begin
    if (|input_valid[input_cnt-1 : 0] && p_state) begin
        output_ins              = input_array[prev_served];
        input_rsp[prev_served]  = output_rsp;
    end
    else
        output_ins = '0;
end

int i;

always @* begin
    n_state = p_state;
    if (!p_state) begin
        if (|input_valid[input_cnt-1 : 0]) begin
            for (i = 0; i < input_cnt; i++) begin
                if (input_valid[(i + prev_served) % input_cnt]) begin
                    prev_served <= ((i + prev_served) % input_cnt);
                    n_state <= 'd1;
                    break;
                end
            end
        end
    end
    else begin
        if (!input_valid[prev_served]) begin
            n_state <= 'd0;
            //input_rsp[prev_served] <= output_rsp;
            //output_ins <= 'd0;
        end
    end
end

endmodule