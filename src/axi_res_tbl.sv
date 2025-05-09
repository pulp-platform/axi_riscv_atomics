// Copyright (c) 2018 ETH Zurich, University of Bologna
//
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// AXI Reservation Table
module axi_res_tbl #(
    parameter int unsigned AXI_ADDR_WIDTH = 0,
    parameter int unsigned AXI_ID_WIDTH = 0,
    parameter int unsigned NUM_RESERVATIONS = 2**AXI_ID_WIDTH
) (
    input  logic                        clk_i,
    input  logic                        rst_ni,
    input  logic [AXI_ADDR_WIDTH-1:0]   check_clr_addr_i,
    input  logic [AXI_ID_WIDTH-1:0]     check_id_i,
    input  logic                        check_clr_excl_i,
    output logic                        check_res_o,
    input  logic                        check_clr_req_i,
    output logic                        check_clr_gnt_o,
    input  logic [AXI_ADDR_WIDTH-1:0]   set_addr_i,
    input  logic [AXI_ID_WIDTH-1:0]     set_id_i,
    input  logic                        set_req_i,
    output logic                        set_gnt_o
);

    localparam integer N_IDS = 2**AXI_ID_WIDTH;

    if (N_IDS <= NUM_RESERVATIONS) begin : gen_standard_table
        // Declarations of Signals and Types
        logic [N_IDS-1:0][AXI_ADDR_WIDTH-1:0]   tbl_d,                      tbl_q;
        logic                                   clr,
                                                set,
                                                match;

        assign match = (tbl_q[check_id_i] == check_clr_addr_i);

        for (genvar i = 0; i < N_IDS; ++i) begin: gen_tbl
            always_comb begin
                tbl_d[i] = tbl_q[i];
                if (set && i == set_id_i) begin
                    tbl_d[i] = set_addr_i;
                end else if (clr && tbl_q[i] == check_clr_addr_i) begin
                    tbl_d[i] = '0;
                end
            end
        end

        // Table-Managing Logic
        always_comb begin
            clr             = 1'b0;
            set             = 1'b0;
            set_gnt_o       = 1'b0;
            check_res_o     = 1'b0;
            check_clr_gnt_o = 1'b0;

            if (check_clr_req_i) begin
                check_clr_gnt_o = 1'b1;
                check_res_o     = match;
                clr             = !(check_clr_excl_i && !match);
            end else if (set_req_i) begin
                set         = 1'b1;
                set_gnt_o   = 1'b1;
            end
        end

        // Registers
        always_ff @(posedge clk_i, negedge rst_ni) begin
            if (~rst_ni) begin
                tbl_q   <= '0;
            end else begin
                tbl_q   <= tbl_d;
            end
        end
    end else begin : gen_prlu_table
        // Declarations of Signals and Types
        logic [NUM_RESERVATIONS-1:0][AXI_ADDR_WIDTH-1:0]   tbl_d, tbl_q;
        logic clr, set, match, matching_set;
        logic [NUM_RESERVATIONS-1:0] plru_used, plru_evict_oh;
        logic [cf_math_pkg::idx_width(NUM_RESERVATIONS)-1:0] plru_evict;
        logic [NUM_RESERVATIONS-1:0][AXI_ID_WIDTH-1:0] tbl_id_d, tbl_id_q;
        logic [NUM_RESERVATIONS-1:0] field_in_use_d, field_in_use_q;

        plru_tree #(
            .ENTRIES(NUM_RESERVATIONS)
        ) i_reservation_plru (
            .clk_i(clk_i),
            .rst_ni(rst_ni),
            .used_i(plru_used),
            .plru_o(plru_evict_oh)
        );

        onehot_to_bin #(
            .ONEHOT_WIDTH(NUM_RESERVATIONS)
        ) i_reservation_plru_bin (
            .onehot(plru_evict_oh),
            .bin(plru_evict)
        );

        always_comb begin
            tbl_d = tbl_q;
            tbl_id_d = tbl_id_q;
            matching_set = 1'b0;
            field_in_use_d = field_in_use_q;
            if (set) begin
                // First reuse existing entry for ID
                for (int i = 0; i < NUM_RESERVATIONS; ++i) begin
                    if (set_id_i == tbl_id_q[i]) begin
                        tbl_d[i] = set_addr_i;
                        plru_used[i] = 1'b1;
                        matching_set = 1'b1;
                        field_in_use_d[i] = 1'b1;
                        break;
                    end
                end
                // Then check for unused entries
                for (int i = 0; i < NUM_RESERVATIONS; ++i) begin
                    if (!field_in_use_q[i] && !matching_set) begin
                        tbl_d[i] = set_addr_i;
                        plru_used[i] = 1'b1;
                        matching_set = 1'b1;
                        field_in_use_d[i] = 1'b1;
                        break;
                    end
                end
                // Finally evict the least recently used entry
                for (int i = 0; i < NUM_RESERVATIONS; ++i) begin
                    if (i == plru_evict && !matching_set) begin
                        tbl_d[i] = set_addr_i;
                        tbl_id_d[i] = set_id_i;
                        plru_used[i] = 1'b1;
                        field_in_use_d[i] = 1'b1;
                    end
                end
            end else if (clr) begin
                for (int i = 0; i < NUM_RESERVATIONS; ++i) begin
                    if (tbl_q[i] == check_clr_addr_i) begin
                        tbl_d[i] = '0;
                        field_in_use_d[i] = 1'b0;
                    end
                end
            end
        end

        // Table-Managing Logic
        always_comb begin
            clr             = 1'b0;
            set             = 1'b0;
            set_gnt_o       = 1'b0;
            check_res_o     = 1'b0;
            check_clr_gnt_o = 1'b0;
            match           = 1'b0;

            if (check_clr_req_i) begin
                for (int i = 0; i < NUM_RESERVATIONS; i++) begin
                    match |= (tbl_q[i] == check_clr_addr_i) &&
                             (tbl_id_q[i] == check_id_i) &&
                             field_in_use_q[i];
                end
                check_clr_gnt_o = 1'b1;
                check_res_o     = match;
                clr             = !(check_clr_excl_i && !match);
            end else if (set_req_i) begin
                set         = 1'b1;
                set_gnt_o   = 1'b1;
            end
        end

        // Registers
        always_ff @(posedge clk_i, negedge rst_ni) begin
            if (~rst_ni) begin
                tbl_q   <= '0;
                tbl_id_q <= '0;
                field_in_use_q <= '0;
            end else begin
                tbl_q   <= tbl_d;
                tbl_id_q <= tbl_id_d;
                field_in_use_q <= field_in_use_d;
            end
        end
    end

    // Validate parameters.
// pragma translate_off
`ifndef VERILATOR
    initial begin: validate_params
        assert (AXI_ADDR_WIDTH > 0)
            else $fatal(1, "AXI_ADDR_WIDTH must be greater than 0!");
        assert (AXI_ID_WIDTH > 0)
            else $fatal(1, "AXI_ID_WIDTH must be greater than 0!");
    end
`endif
// pragma translate_on

endmodule
