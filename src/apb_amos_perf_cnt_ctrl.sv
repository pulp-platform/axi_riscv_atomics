// Copyright 2018 ETH Zurich and University of Bologna.
//
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

`define AMO_PERF_COUNTERS 32

`define REG_RESETN          6'h00 //BASEADDR+0x00
`define REG_START           6'h01 //BASEADDR+0x04
`define REG_STOP            6'h02 //BASEADDR+0x08
`define REG_NUM_AMOS        6'h03 //BASEADDR+0x0C
`define REG_NUM_AMOS_B2B    6'h04 //BASEADDR+0x10
`define REG_STALL_AMOS_B2B  6'h05 //BASEADDR+0x14
`define REG_NUM_COL         6'h06 //BASEADDR+0x18
`define REG_STALL_COL       6'h07 //BASEADDR+0x1C
`define REG_NUM_WF          6'h08 //BASEADDR+0x20

module apb_amos_perf_cnt_ctrl
#(
    parameter APB_ADDR_WIDTH = 12
) (
    input  logic                            HCLK,
    input  logic                            HRESETn,
    input  logic [APB_ADDR_WIDTH-1:0]       PADDR,
    input  logic               [31:0]       PWDATA,
    input  logic                            PWRITE,
    input  logic                            PSEL,
    input  logic                            PENABLE,
    output logic               [31:0]       PRDATA,
    output logic                            PREADY,
    output logic                            PSLVERR,
    input  logic [32-1:0]                   amos_perf_cnt_i [`AMO_PERF_COUNTERS-1:0],
    output logic [`AMO_PERF_COUNTERS-1:0]   amos_perf_cnt_act_o,
    output logic [`AMO_PERF_COUNTERS-1:0]   amos_perf_cnt_rst_no
);

    localparam INT_ADDR_WIDTH = $clog2(`AMO_PERF_COUNTERS);

    logic [INT_ADDR_WIDTH-1:0]      s_apb_addr;
    // FF
    logic [`AMO_PERF_COUNTERS-1:0]  amos_perf_cnt_rst_n;
    logic [`AMO_PERF_COUNTERS-1:0]  amos_perf_cnt_act;
    logic [`AMO_PERF_COUNTERS-1:0]  amos_perf_cnt_act_start;
    logic [`AMO_PERF_COUNTERS-1:0]  amos_perf_cnt_act_stop;

    assign s_apb_addr              = PADDR[INT_ADDR_WIDTH+1:2];
    // Start/stop logic
    assign amos_perf_cnt_act_start = amos_perf_cnt_act |  PWDATA;
    assign amos_perf_cnt_act_stop  = amos_perf_cnt_act & ~PWDATA;
    // Output
    assign amos_perf_cnt_act_o     = amos_perf_cnt_act;
    assign amos_perf_cnt_rst_no    = amos_perf_cnt_rst_n;
    assign PREADY                  = 1'b1;
    assign PSLVERR                 = 1'b0;

    // Read
    always_comb begin
        case (s_apb_addr)
            `REG_START:          begin PRDATA = amos_perf_cnt_act; end
            `REG_STOP:           begin PRDATA = amos_perf_cnt_act; end
            `REG_NUM_AMOS:       begin PRDATA = amos_perf_cnt_i[0]; end
            `REG_NUM_AMOS_B2B:   begin PRDATA = amos_perf_cnt_i[1]; end
            `REG_STALL_AMOS_B2B: begin PRDATA = amos_perf_cnt_i[2]; end
            `REG_NUM_COL:        begin PRDATA = amos_perf_cnt_i[3]; end
            `REG_STALL_COL:      begin PRDATA = amos_perf_cnt_i[4]; end
            `REG_NUM_WF:         begin PRDATA = amos_perf_cnt_i[5]; end
            default:             begin PRDATA = '0; end
        endcase
    end

    // Write
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if(~HRESETn) begin
            amos_perf_cnt_rst_n <= '1;
            amos_perf_cnt_act   <= '0;
        end else begin
            // Default
            amos_perf_cnt_rst_n = '1;

            if (PSEL && PENABLE && PWRITE) begin
                case (s_apb_addr)
                    `REG_RESETN: begin amos_perf_cnt_rst_n <= ~PWDATA; end
                    `REG_START:  begin amos_perf_cnt_act   <= amos_perf_cnt_act_start; end
                    `REG_STOP:   begin amos_perf_cnt_act   <= amos_perf_cnt_act_stop;  end
                endcase
            end
        end
    end

endmodule
