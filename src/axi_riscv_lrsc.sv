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
//  -   The adapter allows at most one read and one write access to be outstanding at any given
//      time.
//  -   The adapter does not support bursts in exclusive accessing.  Only single words can be
//      reserved.
//
// Maintainer: Andreas Kurth <akurth@iis.ee.ethz.ch>

module axi_riscv_lrsc #(
    /// Exclusively-accessible address range (closed interval from ADDR_BEGIN to ADDR_END)
    parameter longint unsigned ADDR_BEGIN = 0,
    parameter longint unsigned ADDR_END = 0,
    /// AXI Parameters
    parameter int unsigned AXI_ADDR_WIDTH = 0,
    parameter int unsigned AXI_ID_WIDTH = 0
) (
    input logic     clk_i,
    input logic     rst_ni,
    AXI_BUS.Master  mst,
    AXI_BUS.Slave   slv
);

    // Declarations of Signals and Types

    logic [AXI_ID_WIDTH-1:0]        art_check_id,
                                    art_set_id,
                                    w_id_d,                     w_id_q;

    logic [AXI_ADDR_WIDTH-1:0]      art_check_addr,
                                    art_clr_addr,
                                    art_set_addr,
                                    rd_clr_addr,
                                    wr_clr_addr,
                                    w_addr_d,                   w_addr_q;

    logic                           art_check_req,              art_check_gnt,
                                    art_clr_req,                art_clr_gnt,
                                    art_set_req,                art_set_gnt,
                                    rd_clr_req,                 rd_clr_gnt,
                                    wr_clr_req,                 wr_clr_gnt;

    logic                           art_check_res;

    logic                           b_excl_d,                   b_excl_q,
                                    r_excl_d,                   r_excl_q;

    typedef enum logic [1:0]    {R_IDLE, R_WAIT_AR, R_WAIT_R} r_state_t;
    r_state_t                       r_state_d,                  r_state_q;

    typedef enum logic [2:0]    {AW_IDLE, W_FORWARD, W_BYPASS, W_WAIT_ART_CLR, W_DROP, B_FORWARD,
                                B_INJECT} w_state_t;
    w_state_t                       w_state_d,                  w_state_q;

    // AR and R Channel

    // Time-Invariant Signal Assignments
    assign mst.ar_addr      = slv.ar_addr;
    assign mst.ar_prot      = slv.ar_prot;
    assign mst.ar_region    = slv.ar_region;
    assign mst.ar_len       = slv.ar_len;
    assign mst.ar_size      = slv.ar_size;
    assign mst.ar_burst     = slv.ar_burst;
    assign mst.ar_lock      = 1'b0;
    assign mst.ar_cache     = slv.ar_cache;
    assign mst.ar_qos       = slv.ar_qos;
    assign mst.ar_id        = slv.ar_id;
    assign mst.ar_user      = slv.ar_user;
    assign slv.r_data       = mst.r_data;
    assign slv.r_last       = mst.r_last;
    assign slv.r_id         = mst.r_id;
    assign slv.r_user       = mst.r_user;

    // FSM for Time-Variant Signal Assignments
    always_comb begin
        mst.ar_valid    = 1'b0;
        slv.ar_ready    = 1'b0;
        mst.r_ready     = 1'b0;
        slv.r_valid     = 1'b0;
        slv.r_resp      = '0;
        art_set_addr    = '0;
        art_set_id      = '0;
        art_set_req     = 1'b0;
        rd_clr_addr     = '0;
        rd_clr_req      = 1'b0;
        r_excl_d        = r_excl_q;
        r_state_d       = r_state_q;

        case (r_state_q)

            R_IDLE: begin
                if (slv.ar_valid) begin
                    if (slv.ar_addr >= ADDR_BEGIN && slv.ar_addr <= ADDR_END && slv.ar_lock &&
                            slv.ar_len == 8'h00) begin
                        // Inside exclusively-accessible address range and exclusive access and no
                        // burst
                        art_set_addr    = slv.ar_addr;
                        art_set_id      = slv.ar_id;
                        art_set_req     = 1'b1;
                        r_excl_d        = 1'b1;
                        if (art_set_gnt) begin
                            mst.ar_valid = 1'b1;
                            if (mst.ar_ready) begin
                                slv.ar_ready = 1'b1;
                                r_state_d = R_WAIT_R;
                            end else begin
                                r_state_d = R_WAIT_AR;
                            end
                        end
                    end else begin
                        // Outside exclusively-accessible address range or regular access or burst
                        r_excl_d = 1'b0;
                        mst.ar_valid = 1'b1;
                        if (mst.ar_ready) begin
                            slv.ar_ready = 1'b1;
                            r_state_d = R_WAIT_R;
                        end else begin
                            r_state_d = R_WAIT_AR;
                        end
                    end
                end
            end

            R_WAIT_AR: begin
                mst.ar_valid = slv.ar_valid;
                slv.ar_ready = mst.ar_ready;
                if (mst.ar_ready && mst.ar_valid) begin
                    r_state_d = R_WAIT_R;
                end
            end

            R_WAIT_R: begin
                mst.r_ready = slv.r_ready;
                slv.r_valid = mst.r_valid;
                if (mst.r_resp[1] == 1'b0) begin
                    slv.r_resp = {1'b0, r_excl_q};
                end else begin
                    slv.r_resp = mst.r_resp;
                end
                if (mst.r_valid && mst.r_ready && mst.r_last) begin
                    r_excl_d    = 1'b0;
                    r_state_d   = R_IDLE;
                end
            end

            default: begin
                r_state_d = R_IDLE;
            end
        endcase
    end

    // AW, W and B Channel

    // Time-Invariant Signal Assignments
    assign mst.aw_addr      = slv.aw_addr;
    assign mst.aw_prot      = slv.aw_prot;
    assign mst.aw_region    = slv.aw_region;
    assign mst.aw_len       = slv.aw_len;
    assign mst.aw_size      = slv.aw_size;
    assign mst.aw_burst     = slv.aw_burst;
    assign mst.aw_lock      = 1'b0;
    assign mst.aw_cache     = slv.aw_cache;
    assign mst.aw_qos       = slv.aw_qos;
    assign mst.aw_id        = slv.aw_id;
    assign mst.aw_user      = slv.aw_user;
    assign mst.w_data       = slv.w_data;
    assign mst.w_strb       = slv.w_strb;
    assign mst.w_user       = slv.w_user;
    assign mst.w_last       = slv.w_last;

    always_comb begin
        w_addr_d    = w_addr_q;
        w_id_d      = w_id_q;
        if (slv.aw_valid && slv.aw_ready) begin
            w_addr_d    = slv.aw_addr;
            w_id_d      = slv.aw_id;
        end
    end

    // FSM for Time-Variant Signal Assignments
    always_comb begin
        mst.aw_valid    = 1'b0;
        slv.aw_ready    = 1'b0;
        mst.w_valid     = 1'b0;
        slv.w_ready     = 1'b0;
        slv.b_valid     = 1'b0;
        mst.b_ready     = 1'b0;
        slv.b_resp      = '0;
        slv.b_id        = '0;
        slv.b_user      = '0;
        art_check_addr  = '0;
        art_check_id    = '0;
        art_check_req   = 1'b0;
        wr_clr_addr     = '0;
        wr_clr_req      = 1'b0;
        b_excl_d        = b_excl_q;
        w_state_d       = w_state_q;

        case (w_state_q)

            AW_IDLE: begin
                if (slv.aw_valid) begin
                    // New AW, and W channel is idle
                    if (slv.aw_addr >= ADDR_BEGIN && slv.aw_addr <= ADDR_END) begin
                        // Inside exclusively-accessible address range
                        if (slv.aw_lock && slv.aw_len == 8'h00) begin
                            // Exclusive access and no burst, so check if reservation exists
                            art_check_addr  = slv.aw_addr;
                            art_check_id    = slv.aw_id;
                            art_check_req   = 1'b1;
                            if (art_check_gnt) begin
                                if (art_check_res) begin
                                    // Yes, so forward downstream
                                    mst.aw_valid = 1'b1;
                                    if (mst.aw_ready) begin
                                        slv.aw_ready    = 1'b1;
                                        b_excl_d        = 1'b1;
                                        w_state_d       = W_FORWARD;
                                    end
                                end else begin
                                    // No, drop in W channel.
                                    slv.aw_ready    = 1'b1;
                                    w_state_d       = W_DROP;
                                end
                            end
                        end else begin
                            // Non-exclusive access or burst, so forward downstream
                            mst.aw_valid = 1'b1;
                            if (mst.aw_ready) begin
                                slv.aw_ready    = 1'b1;
                                w_state_d       = W_FORWARD;
                            end
                        end
                    end else begin
                        // Outside exclusively-accessible address range, so bypass any
                        // modifications.
                        mst.aw_valid = 1'b1;
                        slv.aw_ready = mst.aw_ready;
                        if (slv.aw_ready) begin
                            w_state_d = W_BYPASS;
                        end
                    end
                end
            end

            W_FORWARD: begin
                mst.w_valid = slv.w_valid;
                slv.w_ready = mst.w_ready;
                if (slv.w_valid && slv.w_ready && slv.w_last) begin
                    wr_clr_addr = w_addr_q;
                    wr_clr_req  = 1'b1;
                    if (wr_clr_gnt) begin
                        w_state_d = B_FORWARD;
                    end else begin
                        w_state_d = W_WAIT_ART_CLR;
                    end
                end
            end

            W_BYPASS: begin
                mst.w_valid = slv.w_valid;
                slv.w_ready = mst.w_ready;
                if (slv.w_valid && slv.w_ready && slv.w_last) begin
                    w_state_d = B_FORWARD;
                end
            end

            W_WAIT_ART_CLR: begin
                wr_clr_addr = w_addr_q;
                wr_clr_req  = 1'b1;
                if (wr_clr_gnt) begin
                    w_state_d = B_FORWARD;
                end
            end

            W_DROP: begin
                slv.w_ready = 1'b1;
                if (slv.w_valid && slv.w_last) begin
                    w_state_d = B_INJECT;
                end
            end

            B_FORWARD: begin
                mst.b_ready     = slv.b_ready;
                slv.b_valid     = mst.b_valid;
                slv.b_resp[1]   = mst.b_resp[1];
                slv.b_resp[0]   = (mst.b_resp[1] == 1'b0) ? b_excl_q : mst.b_resp[0];
                slv.b_user      = mst.b_user;
                slv.b_id        = mst.b_id;
                if (slv.b_valid && slv.b_ready) begin
                    b_excl_d    = 1'b0;
                    w_state_d   = AW_IDLE;
                end
            end

            B_INJECT: begin
                slv.b_id = w_id_q;
                slv.b_resp = 2'b00;
                slv.b_valid = 1'b1;
                if (slv.b_ready) begin
                    w_state_d = AW_IDLE;
                end
            end

            default: begin
                w_state_d = AW_IDLE;
            end
        endcase
    end

    // AXI Reservation Table
    axi_res_tbl #(
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .AXI_ID_WIDTH   (AXI_ID_WIDTH)
    ) i_art (
        .clk_i                  (clk_i),
        .rst_ni                 (rst_ni),
        .clr_addr_i             (art_clr_addr),
        .clr_req_i              (art_clr_req),
        .clr_gnt_o              (art_clr_gnt),
        .set_addr_i             (art_set_addr),
        .set_id_i               (art_set_id),
        .set_req_i              (art_set_req),
        .set_gnt_o              (art_set_gnt),
        .check_addr_i           (art_check_addr),
        .check_id_i             (art_check_id),
        .check_res_o            (art_check_res),
        .check_req_i            (art_check_req),
        .check_gnt_o            (art_check_gnt)
    );

    // ART Clear Arbiter
    stream_arbiter #(
        .DATA_T     (logic[AXI_ADDR_WIDTH-1:0]),
        .N_INP      (2)
    ) i_non_excl_acc_arb (
        .clk_i          (clk_i),
        .rst_ni         (rst_ni),
        .inp_data_i     ({rd_clr_addr,  wr_clr_addr}),
        .inp_valid_i    ({rd_clr_req,   wr_clr_req}),
        .inp_ready_o    ({rd_clr_gnt,   wr_clr_gnt}),
        .oup_data_o     (art_clr_addr),
        .oup_valid_o    (art_clr_req),
        .oup_ready_i    (art_clr_gnt)
    );

    // Registers
    always_ff @(posedge clk_i, negedge rst_ni) begin
        if (~rst_ni) begin
            b_excl_q    = 1'b0;
            r_excl_q    = 1'b0;
            r_state_q   = R_IDLE;
            w_addr_q    = '0;
            w_id_q      = '0;
            w_state_q   = AW_IDLE;
        end else begin
            b_excl_q    = b_excl_d;
            r_excl_q    = r_excl_d;
            r_state_q   = r_state_d;
            w_addr_q    = w_addr_d;
            w_id_q      = w_id_d;
            w_state_q   = w_state_d;
        end
    end

endmodule
