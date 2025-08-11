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

// AXI RISC-V LR/SC Adapter
//
// This adapter adds support for AXI4 exclusive accesses to a slave that natively does not support
// exclusive accesses.  It is to be placed between that slave and the upstream master port, so that
// the `mst` port of this module drives the slave and the `slv` port of this module is driven by
// the upstream master.
//
// Exclusive accesses are only enabled for a range of addresses specified through parameters.  All
// addresses within that range are guaranteed to fulfill the constraints described in A7.2 of the
// AXI4 standard, both for normal and exclusive memory accesses.  Addresses outside that range
// behave like a slave that does not support exclusive memory accesses (see AXI4, A7.2.5).
//
// Limitations:
//  -   The adapter does not support bursts in exclusive accessing.  Only single words can be
//      reserved.
//
// Maintainer: Andreas Kurth <akurth@iis.ee.ethz.ch>

`include "axi/typedef.svh"

module axi_riscv_lrsc #(
    /// Exclusively-accessible address range (closed interval from ADDR_BEGIN to ADDR_END)
    parameter longint unsigned ADDR_BEGIN = 0,
    parameter longint unsigned ADDR_END = 0,
    /// AXI Parameters
    parameter int unsigned AXI_ADDR_WIDTH = 0,
    parameter int unsigned AXI_DATA_WIDTH = 0,
    parameter int unsigned AXI_ID_WIDTH = 0,
    parameter int unsigned AXI_USER_WIDTH = 0,
    parameter int unsigned AXI_MAX_READ_TXNS = 0,  // Maximum number of in-flight read transactions
    parameter int unsigned AXI_MAX_WRITE_TXNS = 0, // Maximum number of in-flight write transactions
    parameter bit AXI_USER_AS_ID = 1'b0,           // Use the AXI User signal instead of the AXI ID to track reservations
    parameter int unsigned AXI_USER_ID_MSB = 0,    // MSB of the ID in the user signal
    parameter int unsigned AXI_USER_ID_LSB = 0,    // LSB of the ID in the user signal
    parameter int unsigned AXI_ADDR_LSB = $clog2(AXI_DATA_WIDTH/8), // log2 of granularity for reservations (ignored LSBs)
    /// Enable debug prints (not synthesizable).
    parameter bit DEBUG = 1'b0,
    /// Enable full bandwidth in ID queues
    parameter bit FULL_BANDWIDTH = 1'b1,
    /// Cut combinational path between input and output in ID queues with full bandwidth
    parameter bit CUT_OUP_POP_INP_GNT = 1'b0,
    /// Number of simultaineous reservations (power of 2, <= 2^AXI_ID_WIDTH or <= 2^(AXI_USER_ID_MSB - AXI_USER_ID_LSB + 1))
    parameter int unsigned NUM_RESERVATIONS = 2**(AXI_USER_AS_ID ?
            AXI_USER_ID_MSB - AXI_USER_ID_LSB + 1
            : AXI_ID_WIDTH),
    /// Derived Parameters (do NOT change manually!)
    localparam int unsigned AXI_STRB_WIDTH = AXI_DATA_WIDTH / 8
) (
    input logic                         clk_i,
    input logic                         rst_ni,

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

    typedef logic [AXI_ADDR_WIDTH-1:0]               axi_addr_t;
    typedef logic [AXI_DATA_WIDTH-1:0]               axi_data_t;
    typedef logic [AXI_DATA_WIDTH/8-1:0]             axi_strobe_t;
    typedef logic [AXI_ID_WIDTH-1:0]                 axi_id_t;
    typedef logic [AXI_USER_WIDTH-1:0]               axi_user_t;

    `AXI_TYPEDEF_ALL(axi, axi_addr_t, axi_id_t, axi_data_t, axi_strobe_t, axi_user_t)

    // Bundle structs
    axi_req_t  slv_req,  mst_req;
    axi_resp_t slv_resp, mst_resp;

    // ---------- Pack unrolled SLV interface into structs ----------
    always_comb begin
    slv_req.ar.addr   = slv_ar_addr_i;
    slv_req.ar.prot   = slv_ar_prot_i;
    slv_req.ar.region = slv_ar_region_i;
    slv_req.ar.len    = slv_ar_len_i;
    slv_req.ar.size   = slv_ar_size_i;
    slv_req.ar.burst  = slv_ar_burst_i;
    slv_req.ar.lock   = slv_ar_lock_i;
    slv_req.ar.cache  = slv_ar_cache_i;
    slv_req.ar.qos    = slv_ar_qos_i;
    slv_req.ar.id     = slv_ar_id_i;
    slv_req.ar.user   = slv_ar_user_i;
    slv_req.ar_valid  = slv_ar_valid_i;

    slv_req.aw.addr   = slv_aw_addr_i;
    slv_req.aw.prot   = slv_aw_prot_i;
    slv_req.aw.region = slv_aw_region_i;
    slv_req.aw.atop   = slv_aw_atop_i;
    slv_req.aw.len    = slv_aw_len_i;
    slv_req.aw.size   = slv_aw_size_i;
    slv_req.aw.burst  = slv_aw_burst_i;
    slv_req.aw.lock   = slv_aw_lock_i;
    slv_req.aw.cache  = slv_aw_cache_i;
    slv_req.aw.qos    = slv_aw_qos_i;
    slv_req.aw.id     = slv_aw_id_i;
    slv_req.aw.user   = slv_aw_user_i;
    slv_req.aw_valid  = slv_aw_valid_i;

    slv_req.w.data    = slv_w_data_i;
    slv_req.w.strb    = slv_w_strb_i;
    slv_req.w.user    = slv_w_user_i;
    slv_req.w.last    = slv_w_last_i;
    slv_req.w_valid   = slv_w_valid_i;

    slv_req.r_ready   = slv_r_ready_i;
    slv_req.b_ready   = slv_b_ready_i;
    end

    // ---------- Unpack structs back to unrolled SLV outputs ----------
    always_comb begin
        slv_ar_ready_o = slv_resp.ar_ready;
        slv_aw_ready_o = slv_resp.aw_ready;
        slv_w_ready_o  = slv_resp.w_ready;

        slv_r_valid_o  = slv_resp.r_valid;
        slv_r_data_o   = slv_resp.r.data;
        slv_r_resp_o   = slv_resp.r.resp;
        slv_r_last_o   = slv_resp.r.last;
        slv_r_id_o     = slv_resp.r.id;
        slv_r_user_o   = slv_resp.r.user;

        slv_b_valid_o  = slv_resp.b_valid;
        slv_b_resp_o   = slv_resp.b.resp;
        slv_b_id_o     = slv_resp.b.id;
        slv_b_user_o   = slv_resp.b.user;
    end

    // ---------- Unpack MST req bundle to unrolled MST outputs ----------
    always_comb begin
        mst_ar_addr_o   = mst_req.ar.addr;
        mst_ar_prot_o   = mst_req.ar.prot;
        mst_ar_region_o = mst_req.ar.region;
        mst_ar_len_o    = mst_req.ar.len;
        mst_ar_size_o   = mst_req.ar.size;
        mst_ar_burst_o  = mst_req.ar.burst;
        mst_ar_lock_o   = mst_req.ar.lock;
        mst_ar_cache_o  = mst_req.ar.cache;
        mst_ar_qos_o    = mst_req.ar.qos;
        mst_ar_id_o     = mst_req.ar.id;
        mst_ar_user_o   = mst_req.ar.user;
        mst_ar_valid_o  = mst_req.ar_valid;

        mst_aw_addr_o   = mst_req.aw.addr;
        mst_aw_prot_o   = mst_req.aw.prot;
        mst_aw_region_o = mst_req.aw.region;
        mst_aw_atop_o   = mst_req.aw.atop;
        mst_aw_len_o    = mst_req.aw.len;
        mst_aw_size_o   = mst_req.aw.size;
        mst_aw_burst_o  = mst_req.aw.burst;
        mst_aw_lock_o   = mst_req.aw.lock;
        mst_aw_cache_o  = mst_req.aw.cache;
        mst_aw_qos_o    = mst_req.aw.qos;
        mst_aw_id_o     = mst_req.aw.id;
        mst_aw_user_o   = mst_req.aw.user;
        mst_aw_valid_o  = mst_req.aw_valid;

        mst_w_data_o    = mst_req.w.data;
        mst_w_strb_o    = mst_req.w.strb;
        mst_w_user_o    = mst_req.w.user;
        mst_w_last_o    = mst_req.w.last;
        mst_w_valid_o   = mst_req.w_valid;

        mst_r_ready_o   = mst_req.r_ready;
        mst_b_ready_o   = mst_req.b_ready;
    end

    // ---------- Pack unrolled MST inputs into mst_resp bundle ----------
    always_comb begin
        mst_resp.ar_ready = mst_ar_ready_i;
        mst_resp.aw_ready = mst_aw_ready_i;
        mst_resp.w_ready  = mst_w_ready_i;

        mst_resp.r_valid  = mst_r_valid_i;
        mst_resp.r.data   = mst_r_data_i;
        mst_resp.r.resp   = mst_r_resp_i;
        mst_resp.r.last   = mst_r_last_i;
        mst_resp.r.id     = mst_r_id_i;
        mst_resp.r.user   = mst_r_user_i;

        mst_resp.b_valid  = mst_b_valid_i;
        mst_resp.b.resp   = mst_b_resp_i;
        mst_resp.b.id     = mst_b_id_i;
        mst_resp.b.user   = mst_b_user_i;
    end

    // ---------- LR/SC core (struct-based) ----------
    axi_riscv_lrsc_structs #(
        .ADDR_BEGIN            (ADDR_BEGIN),
        .ADDR_END              (ADDR_END),
        .AXI_ADDR_WIDTH        (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH        (AXI_DATA_WIDTH),
        .AXI_ID_WIDTH          (AXI_ID_WIDTH),
        .AXI_USER_WIDTH        (AXI_USER_WIDTH),
        .AXI_MAX_READ_TXNS     (AXI_MAX_READ_TXNS),
        .AXI_MAX_WRITE_TXNS    (AXI_MAX_WRITE_TXNS),
        .AXI_USER_AS_ID        (AXI_USER_AS_ID),
        .AXI_USER_ID_MSB       (AXI_USER_ID_MSB),
        .AXI_USER_ID_LSB       (AXI_USER_ID_LSB),
        .AXI_ADDR_LSB          (AXI_ADDR_LSB),
        .DEBUG                 (DEBUG),
        .FULL_BANDWIDTH        (FULL_BANDWIDTH),
        .CUT_OUP_POP_INP_GNT   (CUT_OUP_POP_INP_GNT),
        .NUM_RESERVATIONS      (NUM_RESERVATIONS),
        .aw_chan_t             (axi_aw_chan_t),
        .b_chan_t              (axi_b_chan_t),
        .r_chan_t              (axi_r_chan_t),
        .req_t                 (axi_req_t),
        .resp_t                (axi_resp_t)
    ) i_lrsc_structs (
        .clk_i     (clk_i),
        .rst_ni    (rst_ni),
        .slv_req_i (slv_req),
        .slv_resp_o(slv_resp),
        .mst_req_o (mst_req),
        .mst_resp_i(mst_resp)
    );

endmodule
