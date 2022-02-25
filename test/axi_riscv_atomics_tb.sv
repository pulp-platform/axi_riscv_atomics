// Copyright (c) 2019 ETH Zurich, University of Bologna
//
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

`include "axi/assign.svh"

module automatic axi_riscv_atomics_tb;

    // Constants
    parameter NUM_MASTERS    = 32;
    parameter OFFSET         = 16;
    parameter MAX_TIMEOUT    = 1000; // Cycles

    parameter AXI_ADDR_WIDTH = 64;
    parameter AXI_DATA_WIDTH = 64;
    parameter AXI_ID_WIDTH_M = 8;
    parameter AXI_ID_WIDTH_S = AXI_ID_WIDTH_M + $clog2(NUM_MASTERS);
    parameter AXI_USER_WIDTH = 6;

    parameter SYS_DATA_WIDTH = 64;
    parameter SYS_OFFSET_BIT = $clog2(SYS_DATA_WIDTH/8);

    parameter MEM_ADDR_WIDTH = 18;
    parameter MEM_START_ADDR = 128'h0000_0000_0000_0000_0000_0000_0000_0000; //32'h1C00_0000;
    parameter MEM_END_ADDR   = 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF; //MEM_START_ADDR + (2**MEM_ADDR_WIDTH);

    // Signal declarations
    logic clk   = 0;
    logic rst_n = 0;

    // Generate clock
    localparam tCK = 10ns;

    initial begin : clk_gen
        #tCK;
        while (1) begin
            clk <= 1;
            #(tCK/2);
            clk <= 0;
            #(tCK/2);
        end
    end

    initial begin : rst_gen
        rst_n <= 0;
        @(posedge clk);
        #(tCK/2);
        rst_n <= 1;
    end

    initial $timeformat(-9, 2, " ns", 10);

    // Testbench status
    logic finished = 0;
    int unsigned num_errors = 0;

    // AXI bus declarations
    AXI_BUS #(
        .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH ),
        .AXI_DATA_WIDTH ( AXI_DATA_WIDTH ),
        .AXI_ID_WIDTH   ( AXI_ID_WIDTH_S ),
        .AXI_USER_WIDTH ( AXI_USER_WIDTH )
    ) axi_mem();
    AXI_BUS_DV #(
        .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH ),
        .AXI_DATA_WIDTH ( AXI_DATA_WIDTH ),
        .AXI_ID_WIDTH   ( AXI_ID_WIDTH_S ),
        .AXI_USER_WIDTH ( AXI_USER_WIDTH )
    ) axi_mem_dv(clk);

    `AXI_ASSIGN_MONITOR(axi_mem_dv, axi_mem)

    AXI_BUS #(
        .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH ),
        .AXI_DATA_WIDTH ( AXI_DATA_WIDTH ),
        .AXI_ID_WIDTH   ( AXI_ID_WIDTH_S ),
        .AXI_USER_WIDTH ( AXI_USER_WIDTH )
    ) axi_dut();

    // Simulated clusters
    AXI_BUS #(
        .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH ),
        .AXI_DATA_WIDTH ( AXI_DATA_WIDTH ),
        .AXI_ID_WIDTH   ( AXI_ID_WIDTH_M ),
        .AXI_USER_WIDTH ( AXI_USER_WIDTH )
    ) axi_cl[NUM_MASTERS]();

    AXI_BUS_DV #(
        .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH ),
        .AXI_DATA_WIDTH ( AXI_DATA_WIDTH ),
        .AXI_ID_WIDTH   ( AXI_ID_WIDTH_M ),
        .AXI_USER_WIDTH ( AXI_USER_WIDTH )
    ) axi_cl_dv[NUM_MASTERS](
        .clk_i          ( clk            )
    );

    generate
        for (genvar i = 0; i < NUM_MASTERS; i++) begin
            `AXI_ASSIGN(axi_cl[i], axi_cl_dv[i]);
        end
    endgenerate

    // Multiplexer between simulated clusters and atomics adapter
    axi_mux_intf #(
        .SLV_AXI_ID_WIDTH   ( AXI_ID_WIDTH_M ),
        .MST_AXI_ID_WIDTH   ( AXI_ID_WIDTH_S ),
        .AXI_ADDR_WIDTH     ( AXI_ADDR_WIDTH ),
        .AXI_DATA_WIDTH     ( AXI_DATA_WIDTH ),
        .AXI_USER_WIDTH     ( AXI_USER_WIDTH ),
        .NO_SLV_PORTS       ( NUM_MASTERS    ),
        .MAX_W_TRANS        ( 8              ),
        .FALL_THROUGH       ( 1'b1           ),
        .SPILL_AW           ( 1'b0           ),
        .SPILL_W            ( 1'b0           ),
        .SPILL_B            ( 1'b0           ),
        .SPILL_AR           ( 1'b0           ),
        .SPILL_R            ( 1'b0           )
    ) i_axi_mux (
        .clk_i  ( clk     ),
        .rst_ni ( rst_n   ),
        .test_i ( 1'b0    ),
        .slv    ( axi_cl  ),
        .mst    ( axi_dut )
    );

    // Memory accessible over AXI bus
    axi_sim_mem_intf #(
        .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH ),
        .AXI_DATA_WIDTH ( AXI_DATA_WIDTH ),
        .AXI_ID_WIDTH   ( AXI_ID_WIDTH_S ),
        .AXI_USER_WIDTH ( AXI_USER_WIDTH ),
        .APPL_DELAY     ( tCK * 1 / 4    ),
        .ACQ_DELAY      ( tCK * 3 / 4    )
    ) i_axi_sim_mem (
        .clk_i      ( clk     ),
        .rst_ni     ( rst_n   ),
        .axi_slv    ( axi_mem )
    );

    // axi_riscv_amos_wrap #(
    axi_riscv_atomics_wrap #(
        .AXI_ADDR_WIDTH     ( AXI_ADDR_WIDTH ),
        .AXI_DATA_WIDTH     ( AXI_DATA_WIDTH ),
        .AXI_ID_WIDTH       ( AXI_ID_WIDTH_S ),
        .AXI_USER_WIDTH     ( AXI_USER_WIDTH ),
        .AXI_MAX_READ_TXNS  ( 31             ),
        .AXI_MAX_WRITE_TXNS ( 31             ),
        .RISCV_WORD_WIDTH   ( SYS_DATA_WIDTH )
    ) i_axi_atomic_adapter (
        .clk_i    ( clk     ),
        .rst_ni   ( rst_n   ),
        .mst      ( axi_mem ),
        .slv      ( axi_dut )
    );

    // AXI Testbench
    // AXI driver
    tb_axi_pkg::axi_access #(
        .AW( AXI_ADDR_WIDTH ),
        .DW( AXI_DATA_WIDTH ),
        .IW( AXI_ID_WIDTH_M ),
        .UW( AXI_USER_WIDTH ),
        .SW( SYS_DATA_WIDTH ),
        // .TA( 200ps          ),
        // .TT( 700ps          )
        .TA( 0ps          ),
        .TT( 900ps          )
    ) axi_dut_master[NUM_MASTERS];

    generate
        for (genvar i = 0; i < NUM_MASTERS; i++) begin : gen_axi_access
            initial begin
                axi_dut_master[i] = new(i, axi_cl_dv[i]);
            end
        end
    endgenerate

    // Golden model
    // The golden model memory's data width is the system data width
    // Therefore, the golden memory address width must be larger than the
    // actual memory's address width if the data width does not match.
    // This ensures that both memories can store the same amount of bits.
    localparam int unsigned GOLD_MEM_WIDTH = MEM_ADDR_WIDTH + $clog2(AXI_DATA_WIDTH/8) ;// + (AXI_DATA_WIDTH/SYS_DATA_WIDTH) - 1;

    golden_model_pkg::golden_memory #(
        .MEM_ADDR_WIDTH( GOLD_MEM_WIDTH ),
        .MEM_DATA_WIDTH( SYS_DATA_WIDTH ),
        .AXI_ADDR_WIDTH( AXI_ADDR_WIDTH ),
        .AXI_DATA_WIDTH( AXI_DATA_WIDTH ),
        .AXI_ID_WIDTH_M( AXI_ID_WIDTH_M ),
        .AXI_ID_WIDTH_S( AXI_ID_WIDTH_S ),
        .AXI_USER_WIDTH( AXI_USER_WIDTH )
    ) gold_memory = new(axi_mem_dv);

    /*====================================================================
    =                                Main                                =
    ====================================================================*/
    initial begin : main
        // Initialize the AXI drivers
        for (int i = 0; i < NUM_MASTERS; i++) begin
            axi_dut_master[i].reset_master();
        end
        // Wait for reset
        @(posedge clk);
        wait (rst_n);
        // Run tests!
        test_all_amos();
        test_same_address();
        test_amo_write_consistency();
        // test_interleaving(); // Only works on old memory controller
        test_atomic_counter();
        random_amo();

        overtake_r();

        finished = 1;
    end

    /*====================================================================
    =                               Timeout                              =
    ====================================================================*/
    initial begin : timeout_block
        // Signals to check
        automatic int unsigned timeout = 0;
        automatic logic [3:0] handshake = 0;
        // Check for timeout
        @(posedge clk);
        wait (rst_n);

        fork
            while (timeout < MAX_TIMEOUT) begin
                handshake = {axi_dut.aw_valid, axi_dut.aw_ready, axi_dut.ar_valid, axi_dut.ar_ready};
                #100ns;
                @(posedge clk);
                if (handshake != {axi_dut.aw_valid, axi_dut.aw_ready, axi_dut.ar_valid, axi_dut.ar_ready}) begin
                    timeout = 0;
                end else begin
                    timeout += 1;
                end
            end
            while (!finished) begin
                #100ns;
                @(posedge clk);
            end
        join_any

        if (finished && num_errors == 0) begin
            $display("\nSUCCESS\n");
        end else if (finished) begin
            $display("\nFINISHED\n");
            if (num_errors > 0) begin
                $fatal(1, "Encountered %d errors.", num_errors);
            end else begin
                $display("All tests passed.");
            end
        end else begin
            $fatal(1, "TIMEOUT");
        end

        $stop;
    end

    /*====================================================================
    =                            Random tests                            =
    ====================================================================*/
    task automatic random_amo();

        $display("Test random atomic accesses...\n");

        // Create multiple drivers
        for (int i = 0; i < NUM_MASTERS; i++) begin
            fork
                automatic int m = i;
                begin
                    automatic logic [AXI_ADDR_WIDTH-1:0] address;
                    automatic logic [AXI_ID_WIDTH_M-1:0] id;
                    automatic logic [SYS_DATA_WIDTH-1:0] data_init;
                    automatic logic [SYS_DATA_WIDTH-1:0] data_amo;
                    automatic logic [2:0]                size;
                    automatic logic [5:0]                atop;

                    automatic logic [SYS_DATA_WIDTH-1:0] r_data;
                    automatic logic [SYS_DATA_WIDTH-1:0] exp_data;
                    automatic logic [SYS_DATA_WIDTH-1:0] act_data;
                    automatic logic [1:0]                b_resp;
                    automatic logic [1:0]                exp_b_resp;

                    // Make some non-atomic transactions
                    repeat (100) begin
                        void'(randomize(address));
                        void'(randomize(data_init));
                        void'(randomize(id));
                        size = $urandom_range(0,SYS_OFFSET_BIT);
                        create_consistent_transaction(address, size, 0);
                        // Write
                        fork
                            axi_dut_master[m].axi_write(address, data_init, size, id, r_data, b_resp);
                            gold_memory.write(address, data_init, size, id, m, exp_data, exp_b_resp);
                        join
                        assert(b_resp == exp_b_resp) else begin
                            $warning("B (0x%1x) did not match expected (0x%1x)", b_resp, exp_b_resp);
                            num_errors += 1;
                        end
                        // Read
                        fork
                            axi_dut_master[m].axi_read(address, act_data, size, id);
                            gold_memory.read(address, exp_data, size, id, m);
                        join
                        assert(act_data == exp_data) else begin
                            $warning("R (0x%x) did not match expected data (0x%x) at address 0x%x, size 0x%x", act_data, exp_data, address, size);
                            num_errors += 1;
                        end
                    end

                    repeat (500) @(posedge clk);
                    repeat (2000) begin
                        void'(randomize(address));
                        void'(randomize(data_init));
                        void'(randomize(data_amo));
                        void'(randomize(id));
                        void'(randomize(atop));
                        size = $urandom_range(0,SYS_OFFSET_BIT);

                        // Mix in some non-atomic accesses
                        if (atop[3] == 1'b1) begin
                            atop = 6'b0;
                        end
                        // Make transaction valid
                        create_consistent_transaction(address, size, atop);
                        // Execute a write with data init, a AMO with data_amo and read result
                        write_amo_read_cycle(m, address, data_init, data_amo, size, 0, atop);
                        // Wait a random amount of cycles
                        repeat ($urandom_range(100,1000)) @(posedge clk);
                    end
                end
            join_none
        end

        // Wait for all cores to finish
        wait fork;

    endtask : random_amo

    task automatic overtake_r();

        $display("Try to overtake R...\n");
        fork
            begin
                // Create writes to slow down other thread
                automatic logic [AXI_ADDR_WIDTH-1:0] address;
                automatic logic [AXI_ID_WIDTH_M-1:0] id;
                automatic logic [SYS_DATA_WIDTH-1:0] data_init;
                automatic logic [2:0]                size;
                automatic logic [SYS_DATA_WIDTH-1:0] r_data;
                automatic logic [1:0]                b_resp;

                void'(randomize(address));
                void'(randomize(data_init));
                void'(randomize(id));
                size = $urandom_range(0,SYS_OFFSET_BIT);
                create_consistent_transaction(address, size, 0);

                repeat (20000) begin
                    axi_dut_master[0].axi_write(address, data_init, size, id, r_data, b_resp);
                end
            end
            begin
                // Create AMOs
                automatic logic [AXI_ADDR_WIDTH-1:0] address;
                automatic logic [AXI_ID_WIDTH_M-1:0] id;
                automatic logic [SYS_DATA_WIDTH-1:0] data_init;
                automatic logic [SYS_DATA_WIDTH-1:0] data_amo;
                automatic logic [2:0]                size;
                automatic logic [5:0]                atop = 6'b100000;

                repeat (2000) begin
                    void'(randomize(address));
                    void'(randomize(data_init));
                    void'(randomize(data_amo));
                    void'(randomize(id));
                    size = $urandom_range(0,SYS_OFFSET_BIT);

                    // Make transaction valid
                    create_consistent_transaction(address, size, atop);
                    // Execute a write with data init, a AMO with data_amo and read result
                    write_amo_read_cycle(1, address, data_init, data_amo, size, id, atop);
                    // Wait a random amount of cycles
                    // repeat ($urandom_range(100,1000)) @(posedge clk);
                end
            end
        join

    endtask : overtake_r

    /*====================================================================
    =                         Hand crafted tests                         =
    ====================================================================*/
    task automatic test_all_amos();

        localparam AXI_OFFSET_BIT = $clog2(AXI_DATA_WIDTH/8);

        automatic logic [AXI_ADDR_WIDTH-1:0] address;
        automatic logic [AXI_ID_WIDTH_M-1:0] id;
        automatic logic [SYS_DATA_WIDTH-1:0] data_init;
        automatic logic [SYS_DATA_WIDTH-1:0] data_amo;
        automatic logic [2:0]                size;
        automatic logic [1:0]                atomic_transaction;
        automatic logic [2:0]                atomic_operation;
        automatic logic [5:0]                atop;

        $display("Test all possible amos with a single thread...\n");

        // There are 17 AMO instructions + regular write
        for (int i = 0; i < 18; i++) begin
            // Go through all atomic operations
            atomic_operation   = i % 8;
            if (i < 8) begin
                // Atomic load
                atomic_transaction = 2'b10;
            end else if (i < 16) begin
                // Atomic store
                atomic_transaction = 2'b01;
            end else if (i == 16) begin
                // Atomic swap
                atomic_transaction = 2'b11;
                atomic_operation   = 0;
            end else if (i == 17) begin
                // Atomic swap
                atomic_transaction = 2'b0;
                atomic_operation   = 0;
            end
            atop = {atomic_transaction, 1'b0, atomic_operation};

            // Check all possible sizes
            for (int j = 2; j <= SYS_OFFSET_BIT; j++) begin
                // AMOs need to have at least 4 bytes --> start with size = 2
                size = j;

                // Test all possible alignments
                for (int k = 0; k < AXI_DATA_WIDTH/8; k = k+(2**size)) begin

                    // Test instructions with all possible signed/unsigned combinations
                    for (int l = 0; l < 4; l++) begin
                        // Find MSB (size is log2(num_bytes))
                        int unsigned msb = 2**size * 8;
                        void'(randomize(address));
                        void'(randomize(data_init));
                        void'(randomize(data_amo));
                        void'(randomize(id));
                        address[AXI_OFFSET_BIT-1:0] = k;

                        case (l)
                            0 : begin
                                // unsigned/unsigned
                                data_init[msb-1] = 1'b0;
                                data_amo[msb-1]  = 1'b0;
                            end
                            1 : begin
                                // unsigned/signed
                                data_init[msb-1] = 1'b0;
                                data_amo[msb-1]  = 1'b1;
                            end
                            2 : begin
                                // signed/unsigned
                                data_init[msb-1] = 1'b1;
                                data_amo[msb-1]  = 1'b0;
                            end
                            3 : begin
                                // signed/signed
                                data_init[msb-1] = 1'b1;
                                data_amo[msb-1]  = 1'b1;
                            end
                        endcase

                        create_consistent_transaction(address, size, atop);
                        // $display("Test: AMO=%x, Size=%x, Offset=%x, Sign=%x: %x # %x @(%x)", i, j, k, l, data_init, data_amo, address);
                        write_amo_read_cycle(0, address, data_init, data_amo, size, 0, atop);

                    end
                end
            end
        end

    endtask : test_all_amos

    // Test if the adapter inserts the write request correctly
    // ! This only works with a memory controller that allows multiple outstanding transactions
    task automatic test_interleaving();
        // Parameters
        parameter NUM_BURSTS    = 4;
        parameter INIT_MEM_VAL  = 305419896; // 0x12345678
        parameter ATOP_OPERAND  = 43962;     // 0xABBA
        // Variables
        automatic int unsigned addr = MEM_START_ADDR;
        automatic logic [AXI_ID_WIDTH_M-1:0] id;
        automatic logic [SYS_DATA_WIDTH-1:0] r_data;
        automatic logic [2:0] size = SYS_OFFSET_BIT;
        automatic logic [SYS_DATA_WIDTH-1:0] exp_data;
        automatic logic [1:0] b_resp;
        automatic logic [1:0] exp_b_resp;

        automatic axi_test::axi_ax_beat #(.AW(AXI_ADDR_WIDTH), .IW(AXI_ID_WIDTH_M), .UW(AXI_USER_WIDTH)) ax_beat = new;
        automatic axi_test::axi_r_beat  #(.DW(AXI_DATA_WIDTH), .IW(AXI_ID_WIDTH_M), .UW(AXI_USER_WIDTH))  r_beat = new;
        automatic axi_test::axi_w_beat  #(.DW(AXI_DATA_WIDTH), .UW(AXI_USER_WIDTH)) w_beat = new;
        automatic axi_test::axi_b_beat  #(.IW(AXI_ID_WIDTH_M), .UW(AXI_USER_WIDTH)) b_beat = new;

        $display("Test interleaving of write accesses...\n");

        // Initialize memory with 0x12345678 + i
        for (int i = 0; i < 3*NUM_BURSTS; i++) begin
            addr = MEM_START_ADDR + (i*SYS_DATA_WIDTH/8);
            axi_dut_master[i].axi_write(addr, INIT_MEM_VAL + i, size, 1, r_data, b_resp);
        end

        ax_beat.ax_size = size;
        ax_beat.ax_atop = 6'b000000;
        // Generate lots of write requests without sending the data yet
        for (int i = 1; i < NUM_BURSTS; i++) begin
            // Generate AW request
            ax_beat.ax_addr = MEM_START_ADDR + (i*AXI_DATA_WIDTH/8);;
            void'(randomize(id));
            ax_beat.ax_id = id;
            axi_dut_master[i].send_aw(ax_beat);
        end

        // Generate an ATOP request
        ax_beat.ax_addr = MEM_START_ADDR;
        ax_beat.ax_atop = 6'b100000;
        void'(randomize(id));
        ax_beat.ax_id   = id;
        axi_dut_master[0].send_aw(ax_beat);
        // Reset ATOP to regular requests
        ax_beat.ax_atop = 6'b000000;

        // Accept the R response
        fork
            begin
                axi_dut_master[0].recv_r(r_beat);
                r_data = r_beat.r_data[SYS_DATA_WIDTH-1:0];
                if (r_data != INIT_MEM_VAL) begin
                    $display("Test interleaving: ATOP R response was %x. Exp %x", r_data, INIT_MEM_VAL);
                end
            end
        join_none

        // Generate lots of write requests without sending the data yet
        for (int i = NUM_BURSTS; i < 2*NUM_BURSTS; i++) begin
            // Generate AW request
            ax_beat.ax_addr = MEM_START_ADDR + (i*AXI_DATA_WIDTH/8);;
            void'(randomize(id));
            ax_beat.ax_id = id;
            axi_dut_master[i].send_aw(ax_beat);
        end

        fork
            begin
                // Send W data for AMO
                w_beat.w_data = ATOP_OPERAND;
                w_beat.w_last = '1;
                w_beat.w_strb = '0;
                w_beat.w_strb = {{SYS_DATA_WIDTH/8}{1'b1}};
                axi_dut_master[0].send_w(w_beat);
            end
        join_none

        // Keep sending requests and data
        fork
            // Generate further AW requests
            for (int i = 2*NUM_BURSTS; i < 3*NUM_BURSTS; i++) begin
                // Generate AW request
                ax_beat.ax_addr = MEM_START_ADDR + (i*AXI_DATA_WIDTH/8);
                void'(randomize(id));
                ax_beat.ax_id = id;
                axi_dut_master[i].send_aw(ax_beat);
                @(posedge clk);
            end
            // Send the W data
            fork
                for (int i = 1; i < 3*NUM_BURSTS; i++) begin
                    // Generate W request
                    w_beat.w_data = i;
                    w_beat.w_last = '1;
                    w_beat.w_strb = '0;
                    w_beat.w_strb = {{SYS_DATA_WIDTH/8}{1'b1}};
                    axi_dut_master[i].send_w(w_beat);
                    @(posedge clk);
                    @(posedge clk);
                end
            join_none
            // Accept the B response
            for (int i = 0; i < 3*NUM_BURSTS; i++) begin
                fork
                    automatic int j = i;
                    automatic axi_test::axi_b_beat  #(.IW(AXI_ID_WIDTH_M), .UW(AXI_USER_WIDTH)) b_beat_temp = new;
                        axi_dut_master[j].recv_b(b_beat_temp);
                join_none
            end
        join

        // Wait for AMO to finish
        wait fork;

        // Check result
        // Read result of ATOP
        ax_beat.ax_addr = MEM_START_ADDR;
        void'(randomize(id));
        ax_beat.ax_id = id;
        axi_dut_master[0].send_ar(ax_beat);
        axi_dut_master[0].recv_r(r_beat);
        r_data = r_beat.r_data[SYS_DATA_WIDTH-1:0];

        if (r_data != (INIT_MEM_VAL + ATOP_OPERAND)) begin
            $display("Test interleaving: ATOP result is %x. Exp %x", r_data, INIT_MEM_VAL + ATOP_OPERAND);
        end

        // Read all other writes
        for (int i = 1; i < 3*NUM_BURSTS; i++) begin
            // Generate AW request
            ax_beat.ax_addr = MEM_START_ADDR + (i*AXI_DATA_WIDTH/8);;
            void'(randomize(id));
            ax_beat.ax_id = id;
            axi_dut_master[i].send_ar(ax_beat);
            axi_dut_master[i].recv_r(r_beat);
            r_data = r_beat.r_data[SYS_DATA_WIDTH-1:0];
            if (r_data != i) begin
                $display("Test interleaving: Write result is %x. Exp %x", r_data, i);
            end
        end

        #1000ns;

    endtask : test_interleaving

    // Test multiple atomic accesses to the same address
    task automatic test_atomic_counter();
        // Parameters
        parameter NUM_ITERATION = 100;
        parameter COUNTER_ADDR  = 'h01002000;
        // Variables
        automatic logic [SYS_DATA_WIDTH-1:0] r_data;
        automatic logic [2:0] size = SYS_OFFSET_BIT;
        automatic logic [1:0] b_resp;

        $display("Run atomic counter...\n");

        // Initialize to zero
        axi_dut_master[0].axi_write(COUNTER_ADDR, 0, size, 0, r_data, b_resp, 6'b000000);

        // Create multiple drivers
        for (int i = 0; i < NUM_MASTERS; i++) begin
            fork
                automatic int m = i;
                for (int i = 0; i < NUM_ITERATION; i++) begin
                    axi_dut_master[m].axi_write(COUNTER_ADDR, 1, size, m, r_data, b_resp, 6'b100000);
                end
            join_none
        end

        // Wait for all cores to finish
        wait fork;

        // Check result
        axi_dut_master[0].axi_read(COUNTER_ADDR, r_data, size, 0);

        if (r_data == NUM_ITERATION*NUM_MASTERS) begin
            $display("Adder result correct: %d", r_data);
        end else begin
            $display("Adder result wrong: %d (Expected: %d)", r_data, NUM_ITERATION*NUM_MASTERS);
        end

    endtask : test_atomic_counter

    // Test if the adapter protects the atomic region correctly
    task automatic test_same_address();
        // Parameters
        parameter NUM_ITERATION = 10;
        parameter ADDRESS = 'h01004000;
        // Variables
        automatic logic [AXI_ADDR_WIDTH-1:0] address = ADDRESS; // shared by all threads
        automatic logic [SYS_DATA_WIDTH-1:0] r_data_init;
        automatic logic [1:0] b_resp_init;
        automatic logic [SYS_DATA_WIDTH-1:0] exp_data_init;
        automatic logic [1:0] exp_b_resp_init;

        $display("Test random accesses to the same memory location...\n");

        // Initialize memory with 0
        fork
            axi_dut_master[0].axi_write(address, 0, SYS_OFFSET_BIT, 1, r_data_init, b_resp_init);
            gold_memory.write(address, 0, SYS_OFFSET_BIT, 1, 0, exp_data_init, exp_b_resp_init);
        join

        // Spawn multiple processes accessing this address
        for (int i = 0; i < NUM_MASTERS; i++) begin
            fork
                automatic int m = i;
                automatic logic [SYS_OFFSET_BIT-1:0] addr_range;
                automatic logic [AXI_ID_WIDTH_M-1:0] id;
                automatic logic [AXI_ID_WIDTH_S-1:0] s_id;
                automatic logic [SYS_DATA_WIDTH-1:0] w_data;
                automatic logic [2:0]                size = 3'b011;
                automatic logic [SYS_DATA_WIDTH-1:0] r_data;
                automatic logic [SYS_DATA_WIDTH-1:0] exp_data;
                automatic logic [1:0] b_resp;
                automatic logic [1:0] exp_b_resp;
                automatic logic [5:0] atop;
                for (int j = 0; j < NUM_ITERATION; j++) begin
                    // Randomize address but keep it in same word
                    void'(randomize(addr_range));
                    address = ADDRESS + addr_range;
                    void'(randomize(id));
                    void'(randomize(w_data));
                    void'(randomize(atop));
                    void'(randomize(size));
                    size = 3'b011;
                    if (atop[3] | (&atop[5:4] & |atop[2:0])) begin
                        atop = 6'b000000;
                    end
                    create_consistent_transaction(address, size, atop);
                    fork
                        axi_dut_master[m].axi_write(address, w_data, size, id, r_data, b_resp, atop);
                        gold_memory.write(address, w_data, size, id, m, exp_data, exp_b_resp, atop);
                    join
                    assert(b_resp == exp_b_resp) else begin
                        $warning("B (0x%1x) did not match expected (0x%1x)", b_resp, exp_b_resp);
                        num_errors += 1;
                    end
                    if ((atop[5:3] == {axi_pkg::ATOP_ATOMICLOAD, axi_pkg::ATOP_LITTLE_END}) |
                        (atop[5:3] == {axi_pkg::ATOP_ATOMICSWAP, axi_pkg::ATOP_LITTLE_END})) begin
                        assert(r_data == exp_data) else begin
                            $warning("ATOP (0x%x) did not match expected data (0x%x) at address 0x%x at operation: 0x%2x", r_data, exp_data, address, atop);
                            num_errors += 1;
                        end
                    end
                end
            join_none
        end

        // Wait for all cores to finish
        wait fork;

        #1000ns;

    endtask : test_same_address

    // Test if the adapter protects the atomic region correctly
    task automatic test_amo_write_consistency();
        // Parameters
        parameter NUM_ITERATION = 200;
        parameter ADDRESS_START = 'h01004000;
        parameter ADDRESS_END   = 'h01004040;
        // Variables
        automatic logic [AXI_ADDR_WIDTH-1:0] address = ADDRESS_START; // shared by all threads
        automatic logic [SYS_DATA_WIDTH-1:0] r_data_init;
        automatic logic [1:0] b_resp_init;
        automatic logic [SYS_DATA_WIDTH-1:0] exp_data_init;
        automatic logic [1:0] exp_b_resp_init;

        $display("Test AMO and write consistency...\n");

        // Initialize memory with 0
        for (int i = 0; i < (ADDRESS_END-ADDRESS_START)/(SYS_DATA_WIDTH/8); i+=(SYS_DATA_WIDTH/8)) begin
            write_amo_read_cycle(0, ADDRESS_START+i, 0, 0, SYS_OFFSET_BIT, 0, 0);
        end

        // Spawn multiple processes accessing this address
        for (int i = 0; i < NUM_MASTERS; i++) begin
            fork
                automatic int m = i;
                automatic logic [AXI_ADDR_WIDTH-1:0] address;
                automatic logic [AXI_ID_WIDTH_M-1:0] id;
                automatic logic [SYS_DATA_WIDTH-1:0] data_init;
                automatic logic [SYS_DATA_WIDTH-1:0] data_amo;
                automatic logic [2:0]                size;
                automatic logic [5:0]                atop;
                for (int j = 0; j < NUM_ITERATION; j++) begin
                    // Randomize address but keep it in same word
                    address = $urandom_range(ADDRESS_START,ADDRESS_END);
                    void'(randomize(id));
                    void'(randomize(data_init));
                    void'(randomize(data_amo));
                    void'(randomize(atop));
                    atop = create_valid_atop();
                    // void'(randomize(size)); // Half-word not supported by LRSC yet
                    size = SYS_OFFSET_BIT;
                    create_consistent_transaction(address, size, atop);
                    write_amo_read_cycle(m, address, data_init, data_amo, size, id, atop);
                end
            join_none
        end

        // Wait for all cores to finish
        wait fork;

        #1000ns;

    endtask : test_amo_write_consistency

    /*====================================================================
    =                          Helper Functions                          =
    ====================================================================*/
    task automatic create_consistent_transaction(
        inout logic [AXI_ADDR_WIDTH-1:0] address,
        inout logic [2:0]                size,
        input logic [5:0]                amo
    );
        // Transaction must be single burst --> max size is system size
        if (size > SYS_OFFSET_BIT) begin
            size = SYS_OFFSET_BIT;
        end

        // AMO transactions need to be 4 bytes at least
        if ((size < 3'b010) && amo) begin
            size = 3'b010;
        end

        // Address needs to by size aligned
        if (size) begin
            // At least two bytes --> alignment necessary
            for (int i = 0; i < size; i++) begin
                address[i] = 1'b0;
            end
        end
    endtask : create_consistent_transaction

    function automatic logic [5:0] create_valid_atop();
        int random_atop = $urandom_range(0, 16);
        void'(randomize(create_valid_atop));

        if (random_atop < 8) begin
            // Store
            create_valid_atop[5:3] = 3'b010;
        end else if (random_atop < 16) begin
            // Load
            create_valid_atop[5:3] = 3'b100;
        end else begin
            create_valid_atop = 6'b110000;
        end
    endfunction : create_valid_atop

    task automatic write_cycle(
        input int unsigned               driver,
        input logic [AXI_ADDR_WIDTH-1:0] address,
        input logic [SYS_DATA_WIDTH-1:0] data,
        input logic [SYS_DATA_WIDTH-1:0] data_amo,
        input logic [2:0]                size,
        input logic [AXI_ID_WIDTH_M-1:0] id,
        input logic [5:0]                atop
    );
        automatic logic [AXI_ID_WIDTH_M-1:0] trans_id = id;
        automatic logic [SYS_DATA_WIDTH-1:0] r_data;
        automatic logic [SYS_DATA_WIDTH-1:0] exp_data;
        automatic logic [SYS_DATA_WIDTH-1:0] act_data;
        automatic logic [1:0]  b_resp;
        automatic logic [1:0]  exp_b_resp;

        // Write (Need valid memory for atop)
        if (!id) begin
            void'(randomize(trans_id));
        end
        fork
            axi_dut_master[driver].axi_write(address, data, size, trans_id, r_data, b_resp);
            gold_memory.write(address, data, size, trans_id, driver, exp_data, exp_b_resp);
        join
        // AMO
        if (!id) begin
            void'(randomize(trans_id));
        end
        fork
            // Atomic operation
            axi_dut_master[driver].axi_write(address, data_amo, size, trans_id, r_data, b_resp, atop);
            // Golden model
            gold_memory.write(address, data_amo, size, trans_id, driver, exp_data, exp_b_resp, atop);
        join
        assert(b_resp == exp_b_resp) else begin
            $warning("B (0x%1x) did not match expected (0x%1x)", b_resp, exp_b_resp);
            num_errors += 1;
        end
        if ((atop[5:3] == {axi_pkg::ATOP_ATOMICLOAD, axi_pkg::ATOP_LITTLE_END}) |
            (atop[5:3] == {axi_pkg::ATOP_ATOMICSWAP, axi_pkg::ATOP_LITTLE_END})) begin
            assert(r_data == exp_data) else begin
                $warning("ATOP (0x%x) did not match expected data (0x%x) at address 0x%x at operation: 0x%2x", r_data, exp_data, address, atop);
                num_errors += 1;
            end
        end
        // Read result
        if (!id) begin
            void'(randomize(trans_id));
        end
        fork
            axi_dut_master[driver].axi_read(address, act_data, size, trans_id);
            gold_memory.read(address, exp_data, size, trans_id, driver);
        join
        assert(act_data == exp_data) else begin
            $warning("R (0x%x) did not match expected data (0x%x) at address 0x%x, size %x, after operation: 0x%2x (0x%x)", act_data, exp_data, address, size, atop, data);
            num_errors += 1;
        end
    endtask : write_cycle

    task automatic write_amo_read_cycle(
        input int unsigned               driver,
        input logic [AXI_ADDR_WIDTH-1:0] address,
        input logic [SYS_DATA_WIDTH-1:0] data_init,
        input logic [SYS_DATA_WIDTH-1:0] data_amo,
        input logic [2:0]                size,
        input logic [AXI_ID_WIDTH_M-1:0] id,
        input logic [5:0]                atop
    );
        automatic logic [AXI_ID_WIDTH_M-1:0] trans_id = id;
        automatic logic [SYS_DATA_WIDTH-1:0] r_data;
        automatic logic [SYS_DATA_WIDTH-1:0] exp_data;
        automatic logic [SYS_DATA_WIDTH-1:0] act_data;
        automatic logic [1:0]  b_resp;
        automatic logic [1:0]  exp_b_resp;

        // Write (Need valid memory for atop)
        if (!id) begin
            void'(randomize(trans_id));
        end
        fork
            axi_dut_master[driver].axi_write(address, data_init, size, trans_id, r_data, b_resp);
            gold_memory.write(address, data_init, size, trans_id, driver, exp_data, exp_b_resp);
        join
        // AMO
        if (!id) begin
            void'(randomize(trans_id));
        end
        fork
            // Atomic operation
            axi_dut_master[driver].axi_write(address, data_amo, size, trans_id, r_data, b_resp, atop);
            // Golden model
            gold_memory.write(address, data_amo, size, trans_id, driver, exp_data, exp_b_resp, atop);
        join
        assert(b_resp == exp_b_resp) else begin
            $warning("B (0x%1x) did not match expected (0x%1x)", b_resp, exp_b_resp);
            num_errors += 1;
        end
        if ((atop[5:3] == {axi_pkg::ATOP_ATOMICLOAD, axi_pkg::ATOP_LITTLE_END}) |
            (atop[5:3] == {axi_pkg::ATOP_ATOMICSWAP, axi_pkg::ATOP_LITTLE_END})) begin
            assert(r_data == exp_data) else begin
                $warning("ATOP (0x%x) did not match expected data (0x%x) at address 0x%x at operation: 0x%2x", r_data, exp_data, address, atop);
                num_errors += 1;
            end
        end
        // Read result
        if (!id) begin
            void'(randomize(trans_id));
        end
        fork
            axi_dut_master[driver].axi_read(address, act_data, size, trans_id);
            gold_memory.read(address, exp_data, size, trans_id, driver);
        join
        assert(act_data == exp_data) else begin
            $warning("R (0x%x) did not match expected data (0x%x) at address 0x%x, size %x, after operation: 0x%2x (0x%x)", act_data, exp_data, address, size, atop, data_init);
            num_errors += 1;
        end
    endtask : write_amo_read_cycle
endmodule
