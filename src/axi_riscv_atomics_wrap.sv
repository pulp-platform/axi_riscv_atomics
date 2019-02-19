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

// Wrapper for the AXI RISC-V Atomics Adapter that provides AXI ports as individual signals.
//
// See the header of `axi_riscv_atomics` for a description.
//
// Maintainer: Andreas Kurth <akurth@iis.ee.ethz.ch>

module axi_riscv_atomics_wrap #(
    /// AXI Parameters
    parameter int unsigned AXI_ADDR_WIDTH = 0,
    parameter int unsigned AXI_DATA_WIDTH = 0,
    parameter int unsigned AXI_ID_WIDTH = 0,
    parameter int unsigned AXI_USER_WIDTH = 0,
    /// Maximum number of AXI bursts outstanding at the same time
    parameter int unsigned AXI_MAX_WRITE_TXNS = 0,
    // Word width of the widest RISC-V processor that can issue requests to this module.
    // 32 for RV32; 64 for RV64, where both 32-bit (.W suffix) and 64-bit (.D suffix) AMOs are
    // supported if `aw_strb` is set correctly.
    parameter int unsigned RISCV_WORD_WIDTH = 0,
    /// Derived Parameters (do NOT change manually!)
    localparam int unsigned AXI_STRB_WIDTH = AXI_DATA_WIDTH / 8
) (
    input  logic                        clk_i,
    input  logic                        rst_ni,

    /// Slave Interface
    input  logic [AXI_ADDR_WIDTH-1:0]   slv_aw_addr_i,
    input  logic [2:0]                  slv_aw_prot_i,
    input  logic [3:0]                  slv_aw_region_i,
    input  logic [5:0]                  slv_aw_atop_i,
    input  logic [7:0]                  slv_aw_len_i,
    input  logic [2:0]                  slv_aw_size_i,
    input  logic [1:0]                  slv_aw_burst_i,
    input  logic                        slv_aw_lock_i,
    input  logic [3:0]                  slv_aw_cache_i,
    input  logic [3:0]                  slv_aw_qos_i,
    input  logic [AXI_ID_WIDTH-1:0]     slv_aw_id_i,
    input  logic [AXI_USER_WIDTH-1:0]   slv_aw_user_i,
    output logic                        slv_aw_ready_o,
    input  logic                        slv_aw_valid_i,

    input  logic [AXI_ADDR_WIDTH-1:0]   slv_ar_addr_i,
    input  logic [2:0]                  slv_ar_prot_i,
    input  logic [3:0]                  slv_ar_region_i,
    input  logic [7:0]                  slv_ar_len_i,
    input  logic [2:0]                  slv_ar_size_i,
    input  logic [1:0]                  slv_ar_burst_i,
    input  logic                        slv_ar_lock_i,
    input  logic [3:0]                  slv_ar_cache_i,
    input  logic [3:0]                  slv_ar_qos_i,
    input  logic [AXI_ID_WIDTH-1:0]     slv_ar_id_i,
    input  logic [AXI_USER_WIDTH-1:0]   slv_ar_user_i,
    output logic                        slv_ar_ready_o,
    input  logic                        slv_ar_valid_i,

    input  logic [AXI_DATA_WIDTH-1:0]   slv_w_data_i,
    input  logic [AXI_STRB_WIDTH-1:0]   slv_w_strb_i,
    input  logic [AXI_USER_WIDTH-1:0]   slv_w_user_i,
    input  logic                        slv_w_last_i,
    output logic                        slv_w_ready_o,
    input  logic                        slv_w_valid_i,

    output logic [AXI_DATA_WIDTH-1:0]   slv_r_data_o,
    output logic [1:0]                  slv_r_resp_o,
    output logic                        slv_r_last_o,
    output logic [AXI_ID_WIDTH-1:0]     slv_r_id_o,
    output logic [AXI_USER_WIDTH-1:0]   slv_r_user_o,
    input  logic                        slv_r_ready_i,
    output logic                        slv_r_valid_o,

    output logic [1:0]                  slv_b_resp_o,
    output logic [AXI_ID_WIDTH-1:0]     slv_b_id_o,
    output logic [AXI_USER_WIDTH-1:0]   slv_b_user_o,
    input  logic                        slv_b_ready_i,
    output logic                        slv_b_valid_o,

    /// Master Interface
    output logic [AXI_ADDR_WIDTH-1:0]   mst_aw_addr_o,
    output logic [2:0]                  mst_aw_prot_o,
    output logic [3:0]                  mst_aw_region_o,
    output logic [5:0]                  mst_aw_atop_o,
    output logic [7:0]                  mst_aw_len_o,
    output logic [2:0]                  mst_aw_size_o,
    output logic [1:0]                  mst_aw_burst_o,
    output logic                        mst_aw_lock_o,
    output logic [3:0]                  mst_aw_cache_o,
    output logic [3:0]                  mst_aw_qos_o,
    output logic [AXI_ID_WIDTH-1:0]     mst_aw_id_o,
    output logic [AXI_USER_WIDTH-1:0]   mst_aw_user_o,
    input  logic                        mst_aw_ready_i,
    output logic                        mst_aw_valid_o,

    output logic [AXI_ADDR_WIDTH-1:0]   mst_ar_addr_o,
    output logic [2:0]                  mst_ar_prot_o,
    output logic [3:0]                  mst_ar_region_o,
    output logic [7:0]                  mst_ar_len_o,
    output logic [2:0]                  mst_ar_size_o,
    output logic [1:0]                  mst_ar_burst_o,
    output logic                        mst_ar_lock_o,
    output logic [3:0]                  mst_ar_cache_o,
    output logic [3:0]                  mst_ar_qos_o,
    output logic [AXI_ID_WIDTH-1:0]     mst_ar_id_o,
    output logic [AXI_USER_WIDTH-1:0]   mst_ar_user_o,
    input  logic                        mst_ar_ready_i,
    output logic                        mst_ar_valid_o,

    output logic [AXI_DATA_WIDTH-1:0]   mst_w_data_o,
    output logic [AXI_STRB_WIDTH-1:0]   mst_w_strb_o,
    output logic [AXI_USER_WIDTH-1:0]   mst_w_user_o,
    output logic                        mst_w_last_o,
    input  logic                        mst_w_ready_i,
    output logic                        mst_w_valid_o,

    input  logic [AXI_DATA_WIDTH-1:0]   mst_r_data_i,
    input  logic [1:0]                  mst_r_resp_i,
    input  logic                        mst_r_last_i,
    input  logic [AXI_ID_WIDTH-1:0]     mst_r_id_i,
    input  logic [AXI_USER_WIDTH-1:0]   mst_r_user_i,
    output logic                        mst_r_ready_o,
    input  logic                        mst_r_valid_i,

    input  logic [1:0]                  mst_b_resp_i,
    input  logic [AXI_ID_WIDTH-1:0]     mst_b_id_i,
    input  logic [AXI_USER_WIDTH-1:0]   mst_b_user_i,
    output logic                        mst_b_ready_o,
    input  logic                        mst_b_valid_i
);

    // Internal Slave
    AXI_BUS #(
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
        .AXI_ID_WIDTH   (AXI_ID_WIDTH),
        .AXI_USER_WIDTH (AXI_USER_WIDTH)
    ) int_slv (
        aw_addr(slv_aw_addr_i),
        aw_prot(slv_aw_prot_i),
        aw_region(slv_aw_region_i),
        aw_atop(slv_aw_atop_i),
        aw_len(slv_aw_len_i),
        aw_size(slv_aw_size_i),
        aw_burst(slv_aw_burst_i),
        aw_lock(slv_aw_lock_i),
        aw_cache(slv_aw_cache_i),
        aw_qos(slv_aw_qos_i),
        aw_id(slv_aw_id_i),
        aw_user(slv_aw_user_i),
        aw_ready(slv_aw_ready_o),
        aw_valid(slv_aw_valid_i),

        ar_addr(slv_ar_addr_i),
        ar_prot(slv_ar_prot_i),
        ar_region(slv_ar_region_i),
        ar_len(slv_ar_len_i),
        ar_size(slv_ar_size_i),
        ar_burst(slv_ar_burst_i),
        ar_lock(slv_ar_lock_i),
        ar_cache(slv_ar_cache_i),
        ar_qos(slv_ar_qos_i),
        ar_id(slv_ar_id_i),
        ar_user(slv_ar_user_i),
        ar_ready(slv_ar_ready_o),
        ar_valid(slv_ar_valid_i),

        w_valid(slv_w_valid_i),
        w_data(slv_w_data_i),
        w_strb(slv_w_strb_i),
        w_user(slv_w_user_i),
        w_last(slv_w_last_i),
        w_ready(slv_w_ready_o),

        r_data(slv_r_data_o),
        r_resp(slv_r_resp_o),
        r_last(slv_r_last_o),
        r_id(slv_r_id_o),
        r_user(slv_r_user_o),
        r_ready(slv_r_ready_i),
        r_valid(slv_r_valid_o),

        b_resp(slv_b_resp_o),
        b_id(slv_b_id_o),
        b_user(slv_b_user_o),
        b_ready(slv_b_ready_i),
        b_valid(slv_b_valid_o)
    );

    // Internal Master
    AXI_BUS #(
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
        .AXI_ID_WIDTH   (AXI_ID_WIDTH),
        .AXI_USER_WIDTH (AXI_USER_WIDTH)
    ) int_mst (
        aw_addr(mst_aw_addr_o),
        aw_prot(mst_aw_prot_o),
        aw_region(mst_aw_region_o),
        aw_atop(mst_aw_atop_o),
        aw_len(mst_aw_len_o),
        aw_size(mst_aw_size_o),
        aw_burst(mst_aw_burst_o),
        aw_lock(mst_aw_lock_o),
        aw_cache(mst_aw_cache_o),
        aw_qos(mst_aw_qos_o),
        aw_id(mst_aw_id_o),
        aw_user(mst_aw_user_o),
        aw_ready(mst_aw_ready_i),
        aw_valid(mst_aw_valid_o),

        ar_addr(mst_ar_addr_o),
        ar_prot(mst_ar_prot_o),
        ar_region(mst_ar_region_o),
        ar_len(mst_ar_len_o),
        ar_size(mst_ar_size_o),
        ar_burst(mst_ar_burst_o),
        ar_lock(mst_ar_lock_o),
        ar_cache(mst_ar_cache_o),
        ar_qos(mst_ar_qos_o),
        ar_id(mst_ar_id_o),
        ar_user(mst_ar_user_o),
        ar_ready(mst_ar_ready_i),
        ar_valid(mst_ar_valid_o),

        w_valid(mst_w_valid_o),
        w_data(mst_w_data_o),
        w_strb(mst_w_strb_o),
        w_user(mst_w_user_o),
        w_last(mst_w_last_o),
        w_ready(mst_w_ready_i),

        r_data(mst_r_data_i),
        r_resp(mst_r_resp_i),
        r_last(mst_r_last_i),
        r_id(mst_r_id_i),
        r_user(mst_r_user_i),
        r_ready(mst_r_ready_o),
        r_valid(mst_r_valid_i),

        b_resp(mst_b_resp_i),
        b_id(mst_b_id_i),
        b_user(mst_b_user_i),
        b_ready(mst_b_ready_o),
        b_valid(mst_b_valid_i)
    );

    axi_riscv_atomics #(
        .AXI_ADDR_WIDTH     (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH     (AXI_DATA_WIDTH),
        .AXI_ID_WIDTH       (AXI_ID_WIDTH),
        .AXI_USER_WIDTH     (AXI_USER_WIDTH),
        .AXI_MAX_WRITE_TXNS (AXI_MAX_WRITE_TXNS),
        .RISCV_WORD_WIDTH   (RISCV_WORD_WIDTH)
    ) i_atomics (
        .clk_i  (clk_i),
        .rst_ni (rst_ni),
        .mst    (int_mst),
        .slv    (int_slv)
    );

    // Validate parameters.
`ifndef VERILATOR
    initial begin: validate_params
        assert (AXI_STRB_WIDTH == AXI_DATA_WIDTH/8)
            else $fatal(1, "AXI_STRB_WIDTH must equal AXI_DATA_WIDTH/8!");
    end
`endif

endmodule
