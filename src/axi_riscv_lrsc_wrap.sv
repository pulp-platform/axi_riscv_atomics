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

// Wrapper for the AXI RISC-V LR/SC Adapter that provides AXI ports as individual signals.
//
// See the header of `axi_riscv_lrsc` for a description.
//
// Maintainer: Andreas Kurth <akurth@iis.ee.ethz.ch>

module axi_riscv_lrsc_wrap #(
    /// Exclusively-accessible address range (closed interval from ADDR_BEGIN to ADDR_END)
    parameter longint unsigned ADDR_BEGIN = 0,
    parameter longint unsigned ADDR_END = 0,
    /// AXI Parameters
    parameter int unsigned AXI_ADDR_WIDTH = 0,
    parameter int unsigned AXI_DATA_WIDTH = 0,
    parameter int unsigned AXI_ID_WIDTH = 0,
    parameter int unsigned AXI_USER_WIDTH = 0,
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
    ) int_slv ();

    assign int_slv.aw_addr = slv_aw_addr_i;
    assign int_slv.aw_prot = slv_aw_prot_i;
    assign int_slv.aw_region = slv_aw_region_i;
    assign int_slv.aw_atop = slv_aw_atop_i;
    assign int_slv.aw_len = slv_aw_len_i;
    assign int_slv.aw_size = slv_aw_size_i;
    assign int_slv.aw_burst = slv_aw_burst_i;
    assign int_slv.aw_lock = slv_aw_lock_i;
    assign int_slv.aw_cache = slv_aw_cache_i;
    assign int_slv.aw_qos = slv_aw_qos_i;
    assign int_slv.aw_id = slv_aw_id_i;
    assign int_slv.aw_user = slv_aw_user_i;
    assign slv_aw_ready_o = int_slv.aw_ready;
    assign int_slv.aw_valid = slv_aw_valid_i;

    assign int_slv.ar_addr = slv_ar_addr_i;
    assign int_slv.ar_prot = slv_ar_prot_i;
    assign int_slv.ar_region = slv_ar_region_i;
    assign int_slv.ar_len = slv_ar_len_i;
    assign int_slv.ar_size = slv_ar_size_i;
    assign int_slv.ar_burst = slv_ar_burst_i;
    assign int_slv.ar_lock = slv_ar_lock_i;
    assign int_slv.ar_cache = slv_ar_cache_i;
    assign int_slv.ar_qos = slv_ar_qos_i;
    assign int_slv.ar_id = slv_ar_id_i;
    assign int_slv.ar_user = slv_ar_user_i;
    assign slv_ar_ready_o = int_slv.ar_ready;
    assign int_slv.ar_valid = slv_ar_valid_i;

    assign int_slv.w_valid = slv_w_valid_i;
    assign int_slv.w_data = slv_w_data_i;
    assign int_slv.w_strb = slv_w_strb_i;
    assign int_slv.w_user = slv_w_user_i;
    assign int_slv.w_last = slv_w_last_i;
    assign slv_w_ready_o = int_slv.w_ready;

    assign slv_r_data_o = int_slv.r_data;
    assign slv_r_resp_o = int_slv.r_resp;
    assign slv_r_last_o = int_slv.r_last;
    assign slv_r_id_o = int_slv.r_id;
    assign slv_r_user_o = int_slv.r_user;
    assign int_slv.r_ready = slv_r_ready_i;
    assign slv_r_valid_o = int_slv.r_valid;

    assign slv_b_resp_o = int_slv.b_resp;
    assign slv_b_id_o = int_slv.b_id;
    assign slv_b_user_o = int_slv.b_user;
    assign int_slv.b_ready = slv_b_ready_i;
    assign slv_b_valid_o = int_slv.b_valid;

    // Internal Master
    AXI_BUS #(
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
        .AXI_ID_WIDTH   (AXI_ID_WIDTH),
        .AXI_USER_WIDTH (AXI_USER_WIDTH)
    ) int_mst ();

    assign mst_aw_addr_o = int_mst.aw_addr;
    assign mst_aw_prot_o = int_mst.aw_prot;
    assign mst_aw_region_o = int_mst.aw_region;
    assign mst_aw_atop_o = int_mst.aw_atop;
    assign mst_aw_len_o = int_mst.aw_len;
    assign mst_aw_size_o = int_mst.aw_size;
    assign mst_aw_burst_o = int_mst.aw_burst;
    assign mst_aw_lock_o = int_mst.aw_lock;
    assign mst_aw_cache_o = int_mst.aw_cache;
    assign mst_aw_qos_o = int_mst.aw_qos;
    assign mst_aw_id_o = int_mst.aw_id;
    assign mst_aw_user_o = int_mst.aw_user;
    assign int_mst.aw_ready = mst_aw_ready_i;
    assign mst_aw_valid_o = int_mst.aw_valid;

    assign mst_ar_addr_o = int_mst.ar_addr;
    assign mst_ar_prot_o = int_mst.ar_prot;
    assign mst_ar_region_o = int_mst.ar_region;
    assign mst_ar_len_o = int_mst.ar_len;
    assign mst_ar_size_o = int_mst.ar_size;
    assign mst_ar_burst_o = int_mst.ar_burst;
    assign mst_ar_lock_o = int_mst.ar_lock;
    assign mst_ar_cache_o = int_mst.ar_cache;
    assign mst_ar_qos_o = int_mst.ar_qos;
    assign mst_ar_id_o = int_mst.ar_id;
    assign mst_ar_user_o = int_mst.ar_user;
    assign int_mst.ar_ready = mst_ar_ready_i;
    assign mst_ar_valid_o = int_mst.ar_valid;

    assign mst_w_valid_o = int_mst.w_valid;
    assign mst_w_data_o = int_mst.w_data;
    assign mst_w_strb_o = int_mst.w_strb;
    assign mst_w_user_o = int_mst.w_user;
    assign mst_w_last_o = int_mst.w_last;
    assign int_mst.w_ready = mst_w_ready_i;

    assign int_mst.r_data = mst_r_data_i;
    assign int_mst.r_resp = mst_r_resp_i;
    assign int_mst.r_last = mst_r_last_i;
    assign int_mst.r_id = mst_r_id_i;
    assign int_mst.r_user = mst_r_user_i;
    assign mst_r_ready_o = int_mst.r_ready;
    assign int_mst.r_valid = mst_r_valid_i;

    assign int_mst.b_resp = mst_b_resp_i;
    assign int_mst.b_id = mst_b_id_i;
    assign int_mst.b_user = mst_b_user_i;
    assign mst_b_ready_o = int_mst.b_ready;
    assign int_mst.b_valid = mst_b_valid_i;

    axi_riscv_lrsc #(
        .ADDR_BEGIN     (ADDR_BEGIN),
        .ADDR_END       (ADDR_END),
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
        .AXI_ID_WIDTH   (AXI_ID_WIDTH),
        .AXI_USER_WIDTH (AXI_USER_WIDTH)
    ) i_lrsc (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),
        .mst_port   (int_mst),
        .slv_port   (int_slv)
    );

    // Validate parameters.
// pragma translate_off
`ifndef VERILATOR
    initial begin: validate_params
        assert (AXI_STRB_WIDTH == AXI_DATA_WIDTH/8)
            else $fatal(1, "AXI_STRB_WIDTH must equal AXI_DATA_WIDTH/8!");
    end
`endif
// pragma translate_on

endmodule
