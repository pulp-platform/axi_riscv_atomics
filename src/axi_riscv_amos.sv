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

// AXI RISC-V Atomic Operations (AMOs) Adapter
//
// This adapter implements atomic memory operations in accordance with the RVWMO memory consistency
// model.
//
// Interface notes:
// -  This module has combinational paths between AXI inputs and outputs for minimum latency. Add
//    slices upstream or downstream or in both directions if combinatorial paths become too long.
//    The module adheres to the AXI ready/valid dependency specification to prevent combinatorial
//    loops.

module axi_riscv_amos #(
    // AXI Parameters
    parameter int unsigned AXI_ADDR_WIDTH       = 0,
    parameter int unsigned AXI_DATA_WIDTH       = 0,
    parameter int unsigned AXI_ID_WIDTH         = 0,
    parameter int unsigned AXI_USER_WIDTH       = 0,
    // Maximum number of AXI write transactions outstanding at the same time
    parameter int unsigned AXI_MAX_WRITE_TXNS   = 0,
    // Word width of the widest RISC-V processor that can issue requests to this module.
    // 32 for RV32; 64 for RV64, where both 32-bit (.W suffix) and 64-bit (.D suffix) AMOs are
    // supported if `aw_strb` is set correctly.
    parameter int unsigned RISCV_WORD_WIDTH     = 0
) (
    input  logic    clk_i,
    input  logic    rst_ni,
    AXI_BUS.Master  mst_port,
    AXI_BUS.Slave   slv_port
);

    localparam int unsigned OUTSTND_BURSTS_WIDTH = $clog2(AXI_MAX_WRITE_TXNS+1);
    localparam int unsigned AXI_ALU_RATIO        = AXI_DATA_WIDTH/RISCV_WORD_WIDTH;
    localparam int unsigned AXI_STRB_WIDTH       = AXI_DATA_WIDTH/8;

    // State types
    typedef enum logic [1:0] { FEEDTHROUGH_AW, WAIT_ALU, WAIT_AW, REQ_AW } aw_state_t;
    aw_state_t   aw_state_d, aw_state_q;

    typedef enum logic [2:0] { FEEDTHROUGH_W, WAIT_DATA, W_WAIT_RESULT, W_WAIT_CHANNEL, SEND_W } w_state_t;
    w_state_t   w_state_d, w_state_q;

    typedef enum logic [1:0] { FEEDTHROUGH_B, WAIT_B, SEND_B } b_state_t;
    b_state_t   b_state_d, b_state_q;

    typedef enum logic [1:0] { FEEDTHROUGH_AR, WAIT_AR, REQ_AR } ar_state_t;
    ar_state_t  ar_state_d, ar_state_q;

    typedef enum logic [2:0] { FEEDTHROUGH_R, WAIT_DATA_AR, CATCH_R, WAIT_R, SEND_R } r_state_t;
    r_state_t   r_state_d, r_state_q;

    typedef enum logic [1:0] { NONE, INVALID, VALID, STORE } atop_req_t;
    atop_req_t  atop_valid_d, atop_valid_q;

    // Signal declarations
    logic [OUTSTND_BURSTS_WIDTH-1:0]    w_cnt_d, w_cnt_q;
    logic [AXI_ADDR_WIDTH-1:0]          addr_d, addr_q;
    logic [AXI_ID_WIDTH-1:0]            id_d, id_q;
    logic [2:0]                         size_d, size_q;
    logic [AXI_STRB_WIDTH-1:0]          strb_d, strb_q;
    logic [3:0]                         cache_d, cache_q;
    logic [2:0]                         prot_d, prot_q;
    logic [3:0]                         qos_d, qos_q;
    logic [3:0]                         region_d, region_q;
    logic [AXI_USER_WIDTH-1:0]          user_d, user_q;
    logic [AXI_DATA_WIDTH-1:0]          atop_data_d, atop_data_q;
    logic [AXI_DATA_WIDTH-1:0]          read_data_d, read_data_q;
    logic [AXI_DATA_WIDTH-1:0]          write_data_d, write_data_q;
    logic [5:0]                         atop_d, atop_q;
    logic                               data_valid_d, data_valid_q;

    logic                               read_req_d, read_req_q;
    logic                               read_done_d, read_done_q;
    logic                               atop_req_in;
    logic                               valid_atop_req_in;
    logic                               invalid_atop_req_in;
    logic                               valid_atop_req_cu;
    logic                               invalid_atop_req_cu;

    logic                               adapter_ready;

    logic [RISCV_WORD_WIDTH-1:0]    alu_operand_a;
    logic [RISCV_WORD_WIDTH-1:0]    alu_operand_b;
    logic [RISCV_WORD_WIDTH-1:0]    alu_result;
    logic [AXI_DATA_WIDTH-1:0]      alu_result_ext;

    /**
     * Calculate ready signals and channel states
     */

    // Check if all state machines are ready for the next atomic request
    assign adapter_ready = (aw_state_q == FEEDTHROUGH_AW) &&
                           ( w_state_q == FEEDTHROUGH_W ) &&
                           ( b_state_q == FEEDTHROUGH_B ) &&
                           (ar_state_q == FEEDTHROUGH_AR) &&
                           ( r_state_q == FEEDTHROUGH_R );

    // Calculate if the channels are free
    logic aw_valid, aw_ready;
    logic  w_valid,  w_ready;
    logic  b_valid,  b_ready;
    logic ar_valid, ar_ready;
    logic  r_valid,  r_ready;
    logic aw_free, w_free, b_free, ar_free, r_free;

    assign aw_free = ~aw_valid | aw_ready;
    assign  w_free = ~ w_valid |  w_ready;
    assign  b_free = ~ b_valid |  b_ready;
    assign ar_free = ~ar_valid | ar_ready;
    assign  r_free = ~ r_valid |  r_ready;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if(~rst_ni) begin
            aw_valid <= 0;
            aw_ready <= 0;
            w_valid  <= 0;
            w_ready  <= 0;
            b_valid  <= 0;
            b_ready  <= 0;
            ar_valid <= 0;
            ar_ready <= 0;
            r_valid  <= 0;
            r_ready  <= 0;
        end else begin
            aw_valid <= mst.aw_valid;
            aw_ready <= mst.aw_ready;
            w_valid  <= mst.w_valid;
            w_ready  <= mst.w_ready;
            b_valid  <= slv.b_valid;
            b_ready  <= slv.b_ready;
            ar_valid <= mst.ar_valid;
            ar_ready <= mst.ar_ready;
            r_valid  <= slv.r_valid;
            r_ready  <= slv.r_ready;
        end
    end

    // Calculate if the request interferes with the ongoing atomic transaction
    // The protected bytes go from addr_q up to addr_q + (1 << size_q) - 1
    // TODO Bursts need special treatment
    // TODO Some memory controller round the address down
    logic transaction_collision;
    assign transaction_collision = (slv.aw_addr < (     addr_q + (8'h01 <<      size_q))) &
                                   (     addr_q < (slv.aw_addr + (8'h01 << slv.aw_size)));

    always_comb begin : calc_atop_valid
        atop_valid_d = atop_valid_q;
        if (adapter_ready) begin
            atop_valid_d = NONE;
            if (slv.aw_valid && slv.aw_atop) begin
                // Default is invalid request
                atop_valid_d = INVALID;
                // Valid load operation
                if ((slv.aw_atop      ==  axi_pkg::ATOP_ATOMICSWAP) ||
                    (slv.aw_atop[5:3] == {axi_pkg::ATOP_ATOMICLOAD , axi_pkg::ATOP_LITTLE_END})) begin
                    atop_valid_d = VALID;
                end
                // Valid store operation
                if (slv.aw_atop[5:3] == {axi_pkg::ATOP_ATOMICSTORE, axi_pkg::ATOP_LITTLE_END}) begin
                    atop_valid_d = STORE;
                end
                // Invalidate valid request if control signals do not match
                // Burst or exclusive access
                if (slv.aw_len | slv.aw_lock) begin
                    atop_valid_d = INVALID;
                end
                // Unsupported size
                if (slv.aw_size > $clog2(RISCV_WORD_WIDTH/8)) begin
                    atop_valid_d = INVALID;
                end
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin : proc_atop_valid
        if(~rst_ni) begin
            atop_valid_q <= NONE;
        end else begin
            atop_valid_q <= atop_valid_d;
        end
    end

    /**
     * Write Channel: AW, W, B
     */

    /*====================================================================
    =                                 AW                                 =
    ====================================================================*/
    logic [OUTSTND_BURSTS_WIDTH-1:0]  w_cnt_inj_d, w_cnt_inj_q;

    always_comb begin : axi_aw_channel
        // Defaults
        mst.aw_id     = slv.aw_id;
        mst.aw_addr   = slv.aw_addr;
        mst.aw_len    = slv.aw_len;
        mst.aw_size   = slv.aw_size;
        mst.aw_burst  = slv.aw_burst;
        mst.aw_lock   = slv.aw_lock;
        mst.aw_cache  = slv.aw_cache;
        mst.aw_prot   = slv.aw_prot;
        mst.aw_qos    = slv.aw_qos;
        mst.aw_region = slv.aw_region;
        mst.aw_atop   = 6'b0;
        mst.aw_user   = slv.aw_user;
        // Non-AXI signals
        addr_d       = addr_q;
        id_d         = id_q;
        size_d       = size_q;
        atop_d       = atop_q;
        w_cnt_inj_d  = w_cnt_inj_q;
        // State Machine
        aw_state_d   = aw_state_q;

        // Default control
        // Make sure the outstanding beats counter does not overflow
        if (w_cnt_q == AXI_MAX_WRITE_TXNS || (slv.aw_valid && slv.aw_atop)) begin
            // Block if counter is overflowing or atomic request
            mst.aw_valid = 1'b0;
            slv.aw_ready = 1'b0;
        end else if (slv.aw_valid && transaction_collision && !adapter_ready) begin
            // Block requests to the same address as current atomic transaction
            mst.aw_valid = 1'b0;
            slv.aw_ready = 1'b0;
        end else begin
            // Forward
            mst.aw_valid  = slv.aw_valid;
            slv.aw_ready  = mst.aw_ready;
        end

        unique case (aw_state_q)

            FEEDTHROUGH_AW: begin
                // Feedthrough slave to master until atomic operation is detected
                if (slv.aw_valid && slv.aw_atop) begin
                    // Do not forward
                    mst.aw_valid = 1'b0;
                    if (adapter_ready) begin
                        // Acknowledge atomic transaction
                        slv.aw_ready = 1'b1;
                        // Remember request
                        atop_d   = slv.aw_atop;
                        addr_d   = slv.aw_addr;
                        id_d     = slv.aw_id;
                        size_d   = slv.aw_size;
                        cache_d  = slv.aw_cache;
                        prot_d   = slv.aw_prot;
                        qos_d    = slv.aw_qos;
                        region_d = slv.aw_region;
                        user_d   = slv.aw_user;
                        // Go to next state
                        if (atop_valid_d != INVALID) begin
                            aw_state_d = WAIT_ALU;
                        end
                    end else begin
                        // Block request
                        slv.aw_ready  = 1'b0;
                    end
                end

                // Keep counting the W beats
                if (w_cnt_inj_q && mst.w_valid && mst.w_ready && mst.w_last) begin
                    w_cnt_inj_d = w_cnt_inj_q - 1;
                end
            end // FEEDTHROUGH_AW

            WAIT_ALU: begin
                w_cnt_inj_d = 1'b0;
                // If the result is ready, try to write it
                if (read_done_q && data_valid_q) begin
                    // Check if AW channel is free
                    if (aw_free) begin
                        // Block
                        slv.aw_ready = 1'b0;
                        // Make write request
                        mst.aw_valid  = 1'b1;
                        mst.aw_addr   = addr_q;
                        mst.aw_len    = 8'h00;
                        mst.aw_id     = id_q;
                        mst.aw_size   = size_q;
                        mst.aw_burst  = 2'b00;
                        mst.aw_lock   = 1'b0;
                        mst.aw_cache  = cache_q;
                        mst.aw_prot   = prot_q;
                        mst.aw_qos    = qos_q;
                        mst.aw_region = region_q;
                        mst.aw_user   = user_q;
                        // Remember outstanding beats before injected request
                        if (mst.w_valid && mst.w_ready && mst.w_last) begin
                            w_cnt_inj_d = w_cnt_q - 1;
                        end else begin
                            w_cnt_inj_d = w_cnt_q;
                        end
                        // Check if request is acknowledged
                        if (mst.aw_ready) begin
                            aw_state_d = FEEDTHROUGH_AW;
                        end else begin
                            aw_state_d = REQ_AW;
                        end
                    end else begin
                    end
                end
            end // WAIT_ALU

            REQ_AW: begin
                // Block
                slv.aw_ready = 1'b0;
                // Hold write request
                mst.aw_valid  = 1'b1;
                mst.aw_addr   = addr_q;
                mst.aw_len    = 8'h00;
                mst.aw_id     = id_q;
                mst.aw_size   = size_q;
                mst.aw_burst  = 2'b00;
                mst.aw_lock   = 1'b0;
                mst.aw_cache  = cache_q;
                mst.aw_prot   = prot_q;
                mst.aw_qos    = qos_q;
                mst.aw_region = region_q;
                mst.aw_user   = user_q;
                if (mst.aw_ready) begin
                    aw_state_d = FEEDTHROUGH_AW;
                end
                // Keep counting the W beats
                if (w_cnt_inj_q && mst.w_valid && mst.w_ready && mst.w_last) begin
                    w_cnt_inj_d = w_cnt_inj_q - 1;
                end
            end // REQ_AW

            default: aw_state_d = FEEDTHROUGH_AW;

        endcase
    end // axi_aw_channel

    /*====================================================================
    =                                 W                                  =
    ====================================================================*/
    logic [OUTSTND_BURSTS_WIDTH-1:0]  w_cnt_req_d, w_cnt_req_q;

    always_comb begin : axi_w_channel
        // Defaults
        mst.w_data   = slv.w_data;
        mst.w_strb   = slv.w_strb;
        mst.w_last   = slv.w_last;
        mst.w_user   = slv.w_user;
        // Non-AXI signals
        strb_d       = strb_q;
        atop_data_d  = atop_data_q;
        write_data_d = write_data_q;
        data_valid_d = data_valid_q;
        // State Machine
        w_state_d   = w_state_q;
        w_cnt_req_d = w_cnt_req_q;

        // Default control
        // Make sure no data is sent without knowing if it's atomic
        if (w_cnt_q == 0) begin
            // Stall W as it precedes the AW request
            slv.w_ready = 1'b0;
            mst.w_valid = 1'b0;
        end else begin
            mst.w_valid = slv.w_valid;
            slv.w_ready = mst.w_ready;
        end

        unique case (w_state_q)

            FEEDTHROUGH_W: begin
                if (adapter_ready) begin
                    // Reset read flag
                    data_valid_d = 1'b0;
                    write_data_d = '0;

                    if (atop_valid_d != NONE) begin
                        // Check if data is also available and does not belong to previous request
                        if (w_cnt_q == 0) begin
                            // Block downstream
                            mst.w_valid = 1'b0;
                            // Fetch data and wait for all data
                            slv.w_ready  = 1'b1;
                            if (slv.w_valid) begin
                                if (atop_valid_d != INVALID) begin
                                    atop_data_d  = slv.w_data;
                                    strb_d       = slv.w_strb;
                                    data_valid_d = 1'b1;
                                    w_state_d    = W_WAIT_RESULT;
                                end
                            end else begin
                                w_cnt_req_d = '0;
                                w_state_d   = WAIT_DATA;
                            end
                        end else begin
                            // Remember the amount of outstanding bursts and count down
                            if (mst.w_valid && mst.w_ready && mst.w_last) begin
                                w_cnt_req_d = w_cnt_q - 1;
                            end else begin
                                w_cnt_req_d = w_cnt_q;
                            end
                            w_state_d   = WAIT_DATA;
                        end
                    end
                end
            end // FEEDTHROUGH_W

            WAIT_DATA: begin
                // Count W beats until data arrives that belongs to the AMO request
                if (w_cnt_req_q == 0) begin
                    // Block downstream
                    mst.w_valid = 1'b0;
                    // Ready upstream
                    slv.w_ready = 1'b1;

                    if (slv.w_valid) begin
                        if (atop_valid_q == INVALID) begin
                            w_state_d    = FEEDTHROUGH_W;
                        end else begin
                            atop_data_d  = slv.w_data;
                            strb_d       = slv.w_strb;
                            data_valid_d = 1'b1;
                            w_state_d    = W_WAIT_RESULT;
                        end
                    end
                end else if (mst.w_valid && mst.w_ready && mst.w_last) begin
                    w_cnt_req_d = w_cnt_req_q - 1;
                end
            end

            W_WAIT_RESULT: begin
                // If the result is ready, try to write it
                if (read_done_q && data_valid_q && aw_free) begin
                    // Check if W channel is free and make sure data is not interleaved
                    write_data_d = alu_result_ext;
                    if (w_free && w_cnt_q == 0) begin
                        // Block
                        slv.w_ready  = 1'b0;
                        // Send write data
                        mst.w_valid  = 1'b1;
                        mst.w_data   = alu_result_ext;
                        mst.w_last   = 1'b1;
                        mst.w_strb   = strb_q;
                        if (mst.w_ready) begin
                            w_state_d = FEEDTHROUGH_W;
                        end else begin
                            w_state_d = SEND_W;
                        end
                    end else begin
                        w_state_d = W_WAIT_CHANNEL;
                    end
                end
            end // W_WAIT_RESULT

            W_WAIT_CHANNEL: begin
                // Wait to not interleave the data
                if (w_free && w_cnt_inj_q == 0) begin
                    // Block
                    slv.w_ready = 1'b0;
                    // Send write data
                    mst.w_valid  = 1'b1;
                    mst.w_data   = write_data_q;
                    mst.w_last   = 1'b1;
                    mst.w_strb   = strb_q;
                    if (mst.w_ready) begin
                        w_state_d = FEEDTHROUGH_W;
                    end else begin
                        w_state_d = SEND_W;
                    end
                end
            end // W_WAIT_CHANNEL

            SEND_W: begin
                // Block
                slv.w_ready = 1'b0;
                // Send write data
                mst.w_valid  = 1'b1;
                mst.w_data   = write_data_q;
                mst.w_last   = 1'b1;
                mst.w_strb   = strb_q;
                if (mst.w_ready) begin
                    w_state_d = FEEDTHROUGH_W;
                end
            end // SEND_W

            default: w_state_d = FEEDTHROUGH_W;

        endcase
    end // axi_w_channel

    /*====================================================================
    =                                 B                                  =
    ====================================================================*/
    always_comb begin : axi_b_channel
        // Defaults
        mst.b_ready  = slv.b_ready;
        slv.b_id     = mst.b_id;
        slv.b_resp   = mst.b_resp;
        slv.b_user   = mst.b_user;
        slv.b_valid  = mst.b_valid;
        // State Machine
        b_state_d    = b_state_q;

        unique case (b_state_q)

            FEEDTHROUGH_B: begin
                if (adapter_ready && atop_valid_d == INVALID) begin
                    // Inject B resp
                    // Check if the B channel is free
                    if (mst.b_valid) begin
                        b_state_d   = WAIT_B;
                    end else begin
                        mst.b_ready  = 1'b0;
                        // Write B response
                        slv.b_id     = slv.aw_id;
                        slv.b_resp   = axi_pkg::RESP_SLVERR;
                        slv.b_valid  = 1'b1;
                        if (!slv.b_ready) begin
                            b_state_d = SEND_B;
                        end
                    end
                end
            end // FEEDTHROUGH_B

            WAIT_B, SEND_B: begin
                if (b_free || (b_state_q == SEND_B)) begin
                    mst.b_ready  = 1'b0;
                    // Write B response
                    slv.b_id     = id_q;
                    slv.b_resp   = axi_pkg::RESP_SLVERR;
                    slv.b_valid  = 1'b1;
                    if (slv.b_ready) begin
                        b_state_d = FEEDTHROUGH_B;
                    end else begin
                        b_state_d = SEND_B;
                    end
                end
            end // WAIT_B

            default: b_state_d = FEEDTHROUGH_B;

        endcase
    end // axi_b_channel

    // Keep track of outstanding downstream write bursts and responses.
    always_comb begin
        w_cnt_d = w_cnt_q;
        if (mst.aw_valid && mst.aw_ready) begin
            w_cnt_d += 1;
        end
        if (mst.w_valid && mst.w_ready && mst.w_last) begin
            w_cnt_d -= 1;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin : axi_write_channel_ff
        if(~rst_ni) begin
            aw_state_q   <= FEEDTHROUGH_AW;
            w_state_q    <= FEEDTHROUGH_W;
            b_state_q    <= FEEDTHROUGH_B;
            w_cnt_q      <= '0;
            w_cnt_req_q  <= '0;
            w_cnt_inj_q  <= '0;
            addr_q       <= '0;
            id_q         <= '0;
            size_q       <= '0;
            strb_q       <= '0;
            cache_q      <= '0;
            prot_q       <= '0;
            qos_q        <= '0;
            region_q     <= '0;
            user_q       <= '0;
            atop_data_q  <= '0;
            write_data_q <= '0;
            data_valid_q <= '0;
            atop_q       <= 6'b0;
            read_req_q   <= 1'b0;
        end else begin
            aw_state_q   <= aw_state_d;
            w_state_q    <= w_state_d;
            b_state_q    <= b_state_d;
            w_cnt_q      <= w_cnt_d;
            w_cnt_req_q  <= w_cnt_req_d;
            w_cnt_inj_q  <= w_cnt_inj_d;
            addr_q       <= addr_d;
            id_q         <= id_d;
            size_q       <= size_d;
            strb_q       <= strb_d;
            cache_q      <= cache_d;
            prot_q       <= prot_d;
            qos_q        <= qos_d;
            region_q     <= region_d;
            user_q       <= user_d;
            atop_data_q  <= atop_data_d;
            write_data_q <= write_data_d;
            data_valid_q <= data_valid_d;
            atop_q       <= atop_d;
            read_req_q   <= read_req_d;
        end
    end

    /**
    * Read Channel: AR, R
    */

    /*====================================================================
    =                                AR                                  =
    ====================================================================*/
    always_comb begin : axi_AR_channel
        mst.ar_id     = slv.ar_id;
        mst.ar_addr   = slv.ar_addr;
        mst.ar_len    = slv.ar_len;
        mst.ar_size   = slv.ar_size;
        mst.ar_burst  = slv.ar_burst;
        mst.ar_lock   = slv.ar_lock;
        mst.ar_cache  = slv.ar_cache;
        mst.ar_prot   = slv.ar_prot;
        mst.ar_qos    = slv.ar_qos;
        mst.ar_region = slv.ar_region;
        mst.ar_user   = slv.ar_user;
        mst.ar_valid  = 1'b0;
        slv.ar_ready  = 1'b0;

        // State Machine
        ar_state_d  = ar_state_q;

        unique case (ar_state_q)

            FEEDTHROUGH_AR: begin
                // Feed through
                mst.ar_valid  = slv.ar_valid;
                slv.ar_ready  = mst.ar_ready;

                if (adapter_ready) begin
                    if (atop_valid_d == VALID | atop_valid_d == STORE) begin
                        if (slv.ar_valid) begin
                            // Wait until AR is free
                            ar_state_d   = WAIT_AR;
                        end else begin
                            // Acquire channel
                            slv.ar_ready = 1'b0;
                            // Immediately start read request
                            mst.ar_addr  = slv.aw_addr;
                            mst.ar_id    = slv.aw_id;
                            mst.ar_len   = 8'h00;
                            mst.ar_size  = slv.aw_size;
                            mst.ar_burst = 2'b00;
                            mst.ar_lock  = 1'h0;
                            mst.ar_valid = 1'b1;
                            if (!mst.ar_ready) begin
                                // Hold read request but do not depend on AW
                                ar_state_d = REQ_AR;
                            end
                        end
                    end
                end
            end // FEEDTHROUGH_AR

            WAIT_AR: begin
                // Issue read request
                if (ar_free) begin
                    // Inject read request
                    mst.ar_addr  = addr_q;
                    mst.ar_id    = id_q;
                    mst.ar_len   = 8'h00;
                    mst.ar_size  = slv.aw_size;
                    mst.ar_burst = 2'b00;
                    mst.ar_lock  = 1'h0;
                    mst.ar_valid = 1'b1;
                    if (mst.ar_ready) begin
                        // Request acknowledged
                        ar_state_d = FEEDTHROUGH_AR;
                    end else begin
                        // Hold read request
                        ar_state_d = REQ_AR;
                    end
                end else begin
                    // Wait until AR is free
                    mst.ar_valid  = slv.ar_valid;
                    slv.ar_ready  = mst.ar_ready;
                end
            end // WAIT_AR

            REQ_AR: begin
                // Inject read request
                mst.ar_addr  = addr_q;
                mst.ar_id    = id_q;
                mst.ar_len   = 8'h00;
                mst.ar_valid = 1'b1;
                if (mst.ar_ready) begin
                    // Request acknowledged
                    ar_state_d = FEEDTHROUGH_AR;
                end
            end // REQ_AR

            default: ar_state_d = FEEDTHROUGH_AR;

        endcase
    end

    /*====================================================================
    =                                 R                                  =
    ====================================================================*/
    always_comb begin : axi_R_channel

        // Feed through the R channel by default
        mst.r_ready   = slv.r_ready;
        slv.r_id      = mst.r_id;
        slv.r_data    = mst.r_data;
        slv.r_resp    = mst.r_resp;
        slv.r_last    = mst.r_last;
        slv.r_user    = mst.r_user;
        slv.r_valid   = mst.r_valid;

        // State Machine
        read_data_d = read_data_q;
        read_done_d = read_done_q;
        r_state_d   = r_state_q;

        unique case (r_state_q)

            FEEDTHROUGH_R: begin
                if (adapter_ready) begin
                    // Reset read flag
                    read_done_d  = 1'b0;

                    if (atop_valid_d == VALID) begin
                        // Wait for R response to read data
                        r_state_d = WAIT_DATA_AR;
                    end else if (atop_valid_d == INVALID) begin
                        // Send R response
                        // Check if the R channel is free
                        if (mst.r_valid) begin
                            r_state_d = WAIT_R;
                        end else begin
                            // Acquire the R channel
                            slv.r_valid = 1'b0;
                            mst.r_ready = 1'b0;
                            r_state_d   = SEND_R;
                        end
                    end else if (atop_valid_d == STORE) begin
                        // Wait for R response to catch
                        r_state_d = CATCH_R;
                    end
                end
            end // FEEDTHROUGH_R

            WAIT_DATA_AR: begin
                // Read data
                if (mst.r_valid && (mst.r_id == id_q)) begin
                    read_data_d = mst.r_data;
                    read_done_d = 1'b1;
                    if (mst.r_ready) begin
                        r_state_d  = FEEDTHROUGH_R;
                    end
                end
            end // WAIT_DATA_AR

            CATCH_R: begin
                // Atomic store --> block the R response
                if (mst.r_valid && (mst.r_id == id_q)) begin
                    // Block
                    slv.r_valid = 1'b0;
                    // ACK
                    mst.r_ready = 1'b1;
                    // Store data
                    read_data_d = mst.r_data;
                    read_done_d = 1'b1;
                    r_state_d   = FEEDTHROUGH_R;
                end
            end // CATCH_R

            WAIT_R: begin
                // Wait for the R channel to become free
                if (r_free) begin
                    // Block memory
                    mst.r_ready = 1'b0;
                    // Send own R resp
                    slv.r_valid = 1'b1;
                    slv.r_data  = '1;
                    slv.r_id    = id_q;
                    slv.r_resp  = axi_pkg::RESP_SLVERR;
                    slv.r_last  = 1'b1;
                    if (slv.r_ready) begin
                        r_state_d = FEEDTHROUGH_R;
                    end else begin
                        r_state_d = SEND_R;
                    end
                end
            end // WAIT_R

            SEND_R: begin
                // Block memory
                mst.r_ready = 1'b0;
                // Send own R resp
                slv.r_valid = 1'b1;
                slv.r_data  = '1;
                slv.r_id    = id_q;
                slv.r_resp  = axi_pkg::RESP_SLVERR;
                slv.r_last  = 1'b1;
                if (slv.r_ready) begin
                    r_state_d = FEEDTHROUGH_R;
                end
            end // SEND_R

            default: r_state_d = FEEDTHROUGH_R;

        endcase
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin : axi_read_channel_ff
        if(~rst_ni) begin
            ar_state_q  <= FEEDTHROUGH_AR;
            r_state_q   <= FEEDTHROUGH_R;
            read_data_q <= '0;
            read_done_q <= 1'b0;
        end else begin
            ar_state_q  <= ar_state_d;
            r_state_q   <= r_state_d;
            read_data_q <= read_data_d;
            read_done_q <= read_done_d;
        end
    end

    /**
     * ALU
     */

    logic [AXI_ALU_RATIO-1:0][RISCV_WORD_WIDTH-1:0] op_a;
    logic [AXI_ALU_RATIO-1:0][RISCV_WORD_WIDTH-1:0] op_b;
    logic [AXI_ALU_RATIO-1:0][RISCV_WORD_WIDTH-1:0] res;
    logic [AXI_STRB_WIDTH-1:0][7:0]                 strb_ext;

    assign op_a = read_data_q & strb_ext;
    assign op_b = atop_data_q & strb_ext;
    assign alu_result_ext = res;

    generate
        if (AXI_ALU_RATIO == 1) begin
            assign alu_operand_a  = op_a;
            assign alu_operand_b  = op_b;
            assign res            = alu_result;
        end else begin
            assign alu_operand_a  = op_a[addr_q[$clog2(AXI_DATA_WIDTH/8)-1:$clog2(RISCV_WORD_WIDTH/8)]];
            assign alu_operand_b  = op_b[addr_q[$clog2(AXI_DATA_WIDTH/8)-1:$clog2(RISCV_WORD_WIDTH/8)]];
            always_comb begin
                res = '0;
                res[addr_q[$clog2(AXI_DATA_WIDTH/8)-1:$clog2(RISCV_WORD_WIDTH/8)]] = alu_result;
            end
        end
    endgenerate

    generate
        for (genvar i = 0; i < AXI_STRB_WIDTH; i++) begin
            always_comb begin
                if (strb_q[i]) begin
                    strb_ext[i] = 8'hFF;
                end else begin
                    strb_ext[i] = 8'h00;
                end
            end
        end
    endgenerate

    axi_riscv_amos_alu #(
        .DATA_WIDTH ( RISCV_WORD_WIDTH )
    ) i_amo_alu (
        .amo_op_i           ( atop_q        ),
        .amo_operand_a_i    ( alu_operand_a ),
        .amo_operand_b_i    ( alu_operand_b ),
        .amo_result_o       ( alu_result    )
    );

    // Decouple the Interface ports from the internal signals.
    // Setting the interface's signals directly can lead to
    // infinite loops between always_comb blocks in modelsim.
    AXI_BUS #(
      .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH ),
      .AXI_DATA_WIDTH ( AXI_DATA_WIDTH ),
      .AXI_ID_WIDTH   ( AXI_ID_WIDTH   ),
      .AXI_USER_WIDTH ( AXI_USER_WIDTH )
    ) mst();

    AXI_BUS #(
      .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH ),
      .AXI_DATA_WIDTH ( AXI_DATA_WIDTH ),
      .AXI_ID_WIDTH   ( AXI_ID_WIDTH   ),
      .AXI_USER_WIDTH ( AXI_USER_WIDTH )
    ) slv();

    axi_join i_axi_join_mst (
        .in     ( mst      ),
        .out    ( mst_port )
    );

    axi_join i_axi_join_slv (
        .in     ( slv_port ),
        .out    ( slv      )
    );

    // Validate parameters.
// pragma translate_off
`ifndef VERILATOR
    initial begin: validate_params
        assert (AXI_ADDR_WIDTH > 0)
            else $fatal(1, "AXI_ADDR_WIDTH must be greater than 0!");
        assert (AXI_DATA_WIDTH > 0)
            else $fatal(1, "AXI_DATA_WIDTH must be greater than 0!");
        assert (AXI_ID_WIDTH > 0)
            else $fatal(1, "AXI_ID_WIDTH must be greater than 0!");
        assert (AXI_MAX_WRITE_TXNS > 0)
            else $fatal(1, "AXI_MAX_WRITE_TXNS must be greater than 0!");
        assert (RISCV_WORD_WIDTH == 32 || RISCV_WORD_WIDTH == 64)
            else $fatal(1, "RISCV_WORD_WIDTH must be 32 or 64!");
        assert (RISCV_WORD_WIDTH <= AXI_DATA_WIDTH)
            else $fatal(1, "RISCV_WORD_WIDTH must not be greater than AXI_DATA_WIDTH!");
    end
`endif
// pragma translate_on

endmodule
