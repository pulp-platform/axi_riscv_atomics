// Copyright (c) 2026 ZhaoWenyao
// SPDX-License-Identifier: SHL-0.51

// V01 isolated checker test: actual LRSC module and fixed source dependencies.
// No force or modification is applied to the production SoC.
`timescale 1ns/1ps
module tb_lrsc_checker;
  localparam int AXI_ADDR_WIDTH = 32;
  localparam int AXI_DATA_WIDTH = 64;
  localparam int AXI_ID_WIDTH = 2;
  localparam int AXI_USER_WIDTH = 1;
  localparam int AXI_STRB_WIDTH = AXI_DATA_WIDTH/8;
  logic clk_i = 0;
  logic rst_ni = 0;
  always #5 clk_i = ~clk_i;
  logic [AXI_ADDR_WIDTH-1:0] slv_aw_addr_i;
  logic [2:0] slv_aw_prot_i;
  logic [3:0] slv_aw_region_i;
  logic [5:0] slv_aw_atop_i;
  logic [7:0] slv_aw_len_i;
  logic [2:0] slv_aw_size_i;
  logic [1:0] slv_aw_burst_i;
  logic slv_aw_lock_i;
  logic [3:0] slv_aw_cache_i;
  logic [3:0] slv_aw_qos_i;
  logic [AXI_ID_WIDTH-1:0] slv_aw_id_i;
  logic [AXI_USER_WIDTH-1:0] slv_aw_user_i;
  logic slv_aw_ready_o;
  logic slv_aw_valid_i;
  logic [AXI_ADDR_WIDTH-1:0] slv_ar_addr_i;
  logic [2:0] slv_ar_prot_i;
  logic [3:0] slv_ar_region_i;
  logic [7:0] slv_ar_len_i;
  logic [2:0] slv_ar_size_i;
  logic [1:0] slv_ar_burst_i;
  logic slv_ar_lock_i;
  logic [3:0] slv_ar_cache_i;
  logic [3:0] slv_ar_qos_i;
  logic [AXI_ID_WIDTH-1:0] slv_ar_id_i;
  logic [AXI_USER_WIDTH-1:0] slv_ar_user_i;
  logic slv_ar_ready_o;
  logic slv_ar_valid_i;
  logic [AXI_DATA_WIDTH-1:0] slv_w_data_i;
  logic [AXI_STRB_WIDTH-1:0] slv_w_strb_i;
  logic [AXI_USER_WIDTH-1:0] slv_w_user_i;
  logic slv_w_last_i;
  logic slv_w_ready_o;
  logic slv_w_valid_i;
  logic [AXI_DATA_WIDTH-1:0] slv_r_data_o;
  logic [1:0] slv_r_resp_o;
  logic slv_r_last_o;
  logic [AXI_ID_WIDTH-1:0] slv_r_id_o;
  logic [AXI_USER_WIDTH-1:0] slv_r_user_o;
  logic slv_r_ready_i;
  logic slv_r_valid_o;
  logic [1:0] slv_b_resp_o;
  logic [AXI_ID_WIDTH-1:0] slv_b_id_o;
  logic [AXI_USER_WIDTH-1:0] slv_b_user_o;
  logic slv_b_ready_i;
  logic slv_b_valid_o;
  logic [AXI_ADDR_WIDTH-1:0] mst_aw_addr_o;
  logic [2:0] mst_aw_prot_o;
  logic [3:0] mst_aw_region_o;
  logic [5:0] mst_aw_atop_o;
  logic [7:0] mst_aw_len_o;
  logic [2:0] mst_aw_size_o;
  logic [1:0] mst_aw_burst_o;
  logic mst_aw_lock_o;
  logic [3:0] mst_aw_cache_o;
  logic [3:0] mst_aw_qos_o;
  logic [AXI_ID_WIDTH-1:0] mst_aw_id_o;
  logic [AXI_USER_WIDTH-1:0] mst_aw_user_o;
  logic mst_aw_ready_i;
  logic mst_aw_valid_o;
  logic [AXI_ADDR_WIDTH-1:0] mst_ar_addr_o;
  logic [2:0] mst_ar_prot_o;
  logic [3:0] mst_ar_region_o;
  logic [7:0] mst_ar_len_o;
  logic [2:0] mst_ar_size_o;
  logic [1:0] mst_ar_burst_o;
  logic mst_ar_lock_o;
  logic [3:0] mst_ar_cache_o;
  logic [3:0] mst_ar_qos_o;
  logic [AXI_ID_WIDTH-1:0] mst_ar_id_o;
  logic [AXI_USER_WIDTH-1:0] mst_ar_user_o;
  logic mst_ar_ready_i;
  logic mst_ar_valid_o;
  logic [AXI_DATA_WIDTH-1:0] mst_w_data_o;
  logic [AXI_STRB_WIDTH-1:0] mst_w_strb_o;
  logic [AXI_USER_WIDTH-1:0] mst_w_user_o;
  logic mst_w_last_o;
  logic mst_w_ready_i;
  logic mst_w_valid_o;
  logic [AXI_DATA_WIDTH-1:0] mst_r_data_i;
  logic [1:0] mst_r_resp_i;
  logic mst_r_last_i;
  logic [AXI_ID_WIDTH-1:0] mst_r_id_i;
  logic [AXI_USER_WIDTH-1:0] mst_r_user_i;
  logic mst_r_ready_o;
  logic mst_r_valid_i;
  logic [1:0] mst_b_resp_i;
  logic [AXI_ID_WIDTH-1:0] mst_b_id_i;
  logic [AXI_USER_WIDTH-1:0] mst_b_user_i;
  logic mst_b_ready_o;
  logic mst_b_valid_i;
  axi_riscv_lrsc #(
    .ADDR_BEGIN(32'h1000), .ADDR_END(32'h1fff),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH), .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH), .AXI_USER_WIDTH(AXI_USER_WIDTH),
    .AXI_MAX_READ_TXNS(2), .AXI_MAX_WRITE_TXNS(2), .DEBUG(0)
  ) dut (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .slv_aw_addr_i(slv_aw_addr_i),
    .slv_aw_prot_i(slv_aw_prot_i),
    .slv_aw_region_i(slv_aw_region_i),
    .slv_aw_atop_i(slv_aw_atop_i),
    .slv_aw_len_i(slv_aw_len_i),
    .slv_aw_size_i(slv_aw_size_i),
    .slv_aw_burst_i(slv_aw_burst_i),
    .slv_aw_lock_i(slv_aw_lock_i),
    .slv_aw_cache_i(slv_aw_cache_i),
    .slv_aw_qos_i(slv_aw_qos_i),
    .slv_aw_id_i(slv_aw_id_i),
    .slv_aw_user_i(slv_aw_user_i),
    .slv_aw_ready_o(slv_aw_ready_o),
    .slv_aw_valid_i(slv_aw_valid_i),
    .slv_ar_addr_i(slv_ar_addr_i),
    .slv_ar_prot_i(slv_ar_prot_i),
    .slv_ar_region_i(slv_ar_region_i),
    .slv_ar_len_i(slv_ar_len_i),
    .slv_ar_size_i(slv_ar_size_i),
    .slv_ar_burst_i(slv_ar_burst_i),
    .slv_ar_lock_i(slv_ar_lock_i),
    .slv_ar_cache_i(slv_ar_cache_i),
    .slv_ar_qos_i(slv_ar_qos_i),
    .slv_ar_id_i(slv_ar_id_i),
    .slv_ar_user_i(slv_ar_user_i),
    .slv_ar_ready_o(slv_ar_ready_o),
    .slv_ar_valid_i(slv_ar_valid_i),
    .slv_w_data_i(slv_w_data_i),
    .slv_w_strb_i(slv_w_strb_i),
    .slv_w_user_i(slv_w_user_i),
    .slv_w_last_i(slv_w_last_i),
    .slv_w_ready_o(slv_w_ready_o),
    .slv_w_valid_i(slv_w_valid_i),
    .slv_r_data_o(slv_r_data_o),
    .slv_r_resp_o(slv_r_resp_o),
    .slv_r_last_o(slv_r_last_o),
    .slv_r_id_o(slv_r_id_o),
    .slv_r_user_o(slv_r_user_o),
    .slv_r_ready_i(slv_r_ready_i),
    .slv_r_valid_o(slv_r_valid_o),
    .slv_b_resp_o(slv_b_resp_o),
    .slv_b_id_o(slv_b_id_o),
    .slv_b_user_o(slv_b_user_o),
    .slv_b_ready_i(slv_b_ready_i),
    .slv_b_valid_o(slv_b_valid_o),
    .mst_aw_addr_o(mst_aw_addr_o),
    .mst_aw_prot_o(mst_aw_prot_o),
    .mst_aw_region_o(mst_aw_region_o),
    .mst_aw_atop_o(mst_aw_atop_o),
    .mst_aw_len_o(mst_aw_len_o),
    .mst_aw_size_o(mst_aw_size_o),
    .mst_aw_burst_o(mst_aw_burst_o),
    .mst_aw_lock_o(mst_aw_lock_o),
    .mst_aw_cache_o(mst_aw_cache_o),
    .mst_aw_qos_o(mst_aw_qos_o),
    .mst_aw_id_o(mst_aw_id_o),
    .mst_aw_user_o(mst_aw_user_o),
    .mst_aw_ready_i(mst_aw_ready_i),
    .mst_aw_valid_o(mst_aw_valid_o),
    .mst_ar_addr_o(mst_ar_addr_o),
    .mst_ar_prot_o(mst_ar_prot_o),
    .mst_ar_region_o(mst_ar_region_o),
    .mst_ar_len_o(mst_ar_len_o),
    .mst_ar_size_o(mst_ar_size_o),
    .mst_ar_burst_o(mst_ar_burst_o),
    .mst_ar_lock_o(mst_ar_lock_o),
    .mst_ar_cache_o(mst_ar_cache_o),
    .mst_ar_qos_o(mst_ar_qos_o),
    .mst_ar_id_o(mst_ar_id_o),
    .mst_ar_user_o(mst_ar_user_o),
    .mst_ar_ready_i(mst_ar_ready_i),
    .mst_ar_valid_o(mst_ar_valid_o),
    .mst_w_data_o(mst_w_data_o),
    .mst_w_strb_o(mst_w_strb_o),
    .mst_w_user_o(mst_w_user_o),
    .mst_w_last_o(mst_w_last_o),
    .mst_w_ready_i(mst_w_ready_i),
    .mst_w_valid_o(mst_w_valid_o),
    .mst_r_data_i(mst_r_data_i),
    .mst_r_resp_i(mst_r_resp_i),
    .mst_r_last_i(mst_r_last_i),
    .mst_r_id_i(mst_r_id_i),
    .mst_r_user_i(mst_r_user_i),
    .mst_r_ready_o(mst_r_ready_o),
    .mst_r_valid_i(mst_r_valid_i),
    .mst_b_resp_i(mst_b_resp_i),
    .mst_b_id_i(mst_b_id_i),
    .mst_b_user_i(mst_b_user_i),
    .mst_b_ready_o(mst_b_ready_o),
    .mst_b_valid_i(mst_b_valid_i)
  );

  int selected_case;
  int r_checks, r_bad, enq_checks, enq_bad, b_checks, b_bad;
  int upstream_r, upstream_b;

  // These counters validate that the intended predicate was reached. They do
  // not replace any production assertion or model the module's protocol logic.
  always @(posedge clk_i) begin
    if (rst_ni) begin
      if (dut.rifq_oup_req && dut.rifq_oup_gnt) begin
        r_checks++;
        if (!dut.rifq_oup_data_valid) r_bad++;
        $display("LRSC_WINDOW case=%0d R req=%b gnt=%b valid=%b",
                 selected_case, dut.rifq_oup_req, dut.rifq_oup_gnt, dut.rifq_oup_data_valid);
      end
      if (dut.mst_aw_valid && dut.mst_aw_ready) begin
        enq_checks++;
        if (!dut.wifq_inp_gnt) enq_bad++;
        $display("LRSC_WINDOW case=%0d ENQ valid=%b ready=%b grant=%b",
                 selected_case, dut.mst_aw_valid, dut.mst_aw_ready, dut.wifq_inp_gnt);
      end
      if (dut.wifq_oup_req && dut.wifq_oup_gnt) begin
        b_checks++;
        if (!dut.wifq_oup_data_valid) b_bad++;
        $display("LRSC_WINDOW case=%0d B req=%b gnt=%b valid=%b",
                 selected_case, dut.wifq_oup_req, dut.wifq_oup_gnt, dut.wifq_oup_data_valid);
      end
      if (slv_r_valid_o && slv_r_ready_i) begin
        upstream_r++;
        if (selected_case == 0 &&
            {slv_r_id_o,slv_r_resp_o,slv_r_last_o,slv_r_data_o} !==
            {2'd1,2'b00,1'b1,64'h0123456789abcdef})
          $fatal(1,"STIMULUS_ERROR normal R result mismatch");
      end
      if (slv_b_valid_o && slv_b_ready_i) begin
        upstream_b++;
        if (selected_case == 0 && {slv_b_id_o,slv_b_resp_o} !== {2'd2,2'b00})
          $fatal(1,"STIMULUS_ERROR normal B result mismatch");
      end
    end
  end

  task automatic send_ar;
    @(negedge clk_i);
    slv_ar_addr_i=32'h3000; slv_ar_id_i=1; slv_ar_len_i=0;
    slv_ar_size_i=3; slv_ar_burst_i=1; slv_ar_valid_i=1;
    for (int cycle=0;cycle<32;cycle++) begin
      @(posedge clk_i);
      if (slv_ar_ready_o === 1'b1) begin
        @(negedge clk_i); slv_ar_valid_i=0; return;
      end
    end
    $fatal(1,"STIMULUS_ERROR AR handshake timeout");
  endtask

  task automatic send_r;
    @(negedge clk_i);
    mst_r_id_i=1; mst_r_data_i=64'h0123456789abcdef;
    mst_r_resp_i=0; mst_r_last_i=1; mst_r_valid_i=1;
    #1;
    if (selected_case == 1 &&
        {dut.rifq_oup_req,dut.rifq_oup_gnt,dut.rifq_oup_data_valid} !== 3'b110)
      $fatal(1,"STIMULUS_ERROR bad R predicate not reached");
    for (int cycle=0;cycle<32;cycle++) begin
      @(posedge clk_i);
      if (mst_r_ready_o === 1'b1) begin
        @(negedge clk_i); mst_r_valid_i=0; return;
      end
    end
    $fatal(1,"STIMULUS_ERROR R handshake timeout");
  endtask

  task automatic send_aw;
    @(negedge clk_i);
    slv_aw_addr_i=32'h3008; slv_aw_id_i=2; slv_aw_len_i=0;
    slv_aw_size_i=3; slv_aw_burst_i=1; slv_aw_valid_i=1;
    for (int cycle=0;cycle<32;cycle++) begin
      @(posedge clk_i);
      if (slv_aw_ready_o === 1'b1) begin
        @(negedge clk_i); slv_aw_valid_i=0; return;
      end
    end
    $fatal(1,"STIMULUS_ERROR AW handshake timeout");
  endtask

  task automatic send_w;
    @(negedge clk_i);
    slv_w_data_i=64'h123456789abcdef0; slv_w_strb_i='1;
    slv_w_last_i=1; slv_w_valid_i=1;
    for (int cycle=0;cycle<32;cycle++) begin
      @(posedge clk_i);
      if (slv_w_ready_o === 1'b1) begin
        @(negedge clk_i); slv_w_valid_i=0; return;
      end
    end
    $fatal(1,"STIMULUS_ERROR W handshake timeout");
  endtask

  task automatic send_b(input bit corrupt_wifq_valid);
    @(negedge clk_i);
    mst_b_id_i=2; mst_b_resp_i=0; mst_b_valid_i=1;
    if (corrupt_wifq_valid) force dut.wifq_oup_data_valid = 1'b0;
    #1;
    if (corrupt_wifq_valid &&
        ({dut.wifq_oup_req,dut.wifq_oup_gnt,dut.wifq_oup_data_valid} !== 3'b110 ||
         dut.b_status_oup_valid !== 1'b1))
      $fatal(1,"STIMULUS_ERROR bad B predicate/Bstatus isolation not reached");
    for (int cycle=0;cycle<32;cycle++) begin
      @(posedge clk_i);
      if (mst_b_ready_o === 1'b1) begin
        @(negedge clk_i);
        mst_b_valid_i=0;
        if (corrupt_wifq_valid) release dut.wifq_oup_data_valid;
        return;
      end
    end
    $fatal(1,"STIMULUS_ERROR B handshake timeout");
  endtask

  initial begin
    selected_case=0;
    r_checks=0; r_bad=0; enq_checks=0; enq_bad=0; b_checks=0; b_bad=0;
    upstream_r=0; upstream_b=0;
    if ($value$plusargs("CASE=%d",selected_case)) begin end
    if (selected_case < 0 || selected_case > 3)
      $fatal(1,"CASE must be 0 normal, 1 badR, 2 enqueue fault, or 3 WIFQ B fault");
    slv_aw_addr_i = '0;
    slv_aw_prot_i = '0;
    slv_aw_region_i = '0;
    slv_aw_atop_i = '0;
    slv_aw_len_i = '0;
    slv_aw_size_i = '0;
    slv_aw_burst_i = '0;
    slv_aw_lock_i = '0;
    slv_aw_cache_i = '0;
    slv_aw_qos_i = '0;
    slv_aw_id_i = '0;
    slv_aw_user_i = '0;
    slv_aw_valid_i = '0;
    slv_ar_addr_i = '0;
    slv_ar_prot_i = '0;
    slv_ar_region_i = '0;
    slv_ar_len_i = '0;
    slv_ar_size_i = '0;
    slv_ar_burst_i = '0;
    slv_ar_lock_i = '0;
    slv_ar_cache_i = '0;
    slv_ar_qos_i = '0;
    slv_ar_id_i = '0;
    slv_ar_user_i = '0;
    slv_ar_valid_i = '0;
    slv_w_data_i = '0;
    slv_w_strb_i = '0;
    slv_w_user_i = '0;
    slv_w_last_i = '0;
    slv_w_valid_i = '0;
    slv_r_ready_i = '0;
    slv_b_ready_i = '0;
    mst_aw_ready_i = '0;
    mst_ar_ready_i = '0;
    mst_w_ready_i = '0;
    mst_r_data_i = '0;
    mst_r_resp_i = '0;
    mst_r_last_i = '0;
    mst_r_id_i = '0;
    mst_r_user_i = '0;
    mst_r_valid_i = '0;
    mst_b_resp_i = '0;
    mst_b_id_i = '0;
    mst_b_user_i = '0;
    mst_b_valid_i = '0;
    slv_r_ready_i=1; slv_b_ready_i=1;
    mst_aw_ready_i=1; mst_ar_ready_i=1; mst_w_ready_i=1;
    repeat(4) @(negedge clk_i);
    rst_ni=1;
    repeat(2) @(negedge clk_i);
    case (selected_case)
      0: begin send_ar(); send_r(); send_aw(); send_w(); send_b(0); end
      1: begin
        // Unsolicited R from the external slave, without any prior AR.
        send_r();
      end
      2: begin
        // Enqueue failure cannot normally be produced through external ports:
        // AW control itself requires wifq_inp_gnt. This one-cycle isolated fault
        // proves only checker sensitivity, not a reachable functional bug.
        @(negedge clk_i);
        force dut.mst_aw_valid=1'b1;
        force dut.mst_aw_ready=1'b1;
        force dut.wifq_inp_gnt=1'b0;
        #1;
        if ({dut.mst_aw_valid,dut.mst_aw_ready,dut.wifq_inp_gnt} !== 3'b110)
          $fatal(1,"STIMULUS_ERROR enqueue fault predicate not reached");
        @(posedge clk_i);
        @(negedge clk_i);
        release dut.mst_aw_valid;
        release dut.mst_aw_ready;
        release dut.wifq_inp_gnt;
      end
      3: begin
        // A legitimate AW/W establishes Bstatus first. A raw unsolicited B
        // would trigger a different existing Bstatus assertion in both versions.
        send_aw(); send_w(); send_b(1);
      end
    endcase
    repeat(6) @(negedge clk_i);
    if (r_bad !== (selected_case==1) || enq_bad !== (selected_case==2) ||
        b_bad !== (selected_case==3))
      $fatal(1,"STIMULUS_ERROR target bad-predicate counts R=%0d ENQ=%0d B=%0d",
             r_bad,enq_bad,b_bad);
    if (r_checks !== int'(selected_case==0 || selected_case==1) ||
        enq_checks !== int'(selected_case!=1) ||
        b_checks !== int'(selected_case==0 || selected_case==3))
      $fatal(1,"STIMULUS_ERROR target check counts R=%0d ENQ=%0d B=%0d",
             r_checks,enq_checks,b_checks);
    if (selected_case==0 &&
        (r_checks!==1 || enq_checks!==1 || b_checks!==1 || upstream_r!==1 || upstream_b!==1))
      $fatal(1,"STIMULUS_ERROR normal handshake/check count mismatch");
    $display("LRSC_STIMULUS_DONE case=%0d r_checks=%0d r_bad=%0d enq_checks=%0d enq_bad=%0d b_checks=%0d b_bad=%0d upstream_r=%0d upstream_b=%0d",
             selected_case,r_checks,r_bad,enq_checks,enq_bad,b_checks,b_bad,upstream_r,upstream_b);
    $finish;
  end
  initial begin
    #5000;
    $fatal(1,"STIMULUS_ERROR unit timeout");
  end
endmodule
