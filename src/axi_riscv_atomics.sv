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

// AXI RISC-V Atomics ("A" Extension) Adapter
//
// This AXI adapter implements the RISC-V "A" extension and adheres to the RVWMO memory consistency
// model.
//
// Maintainer: Andreas Kurth <akurth@iis.ee.ethz.ch>

module axi_riscv_atomics #(
    /// AXI Parameters
    parameter int unsigned AXI_ADDR_WIDTH = 0,
    parameter int unsigned AXI_DATA_WIDTH = 0,
    parameter int unsigned AXI_ID_WIDTH = 0,
    parameter int unsigned AXI_USER_WIDTH = 0,
    // Maximum number of AXI write bursts outstanding at the same time
    parameter int unsigned AXI_MAX_WRITE_TXNS = 0,
    // Word width of the widest RISC-V processor that can issue requests to this module.
    // 32 for RV32; 64 for RV64, where both 32-bit (.W suffix) and 64-bit (.D suffix) AMOs are
    // supported if `aw_strb` is set correctly.
    parameter int unsigned RISCV_WORD_WIDTH = 0
) (
    input logic     clk_i,
    input logic     rst_ni,
    AXI_BUS.Master  mst,
    AXI_BUS.Slave   slv
);

    // Make the entire address range exclusively accessible. Since the AMO adapter does not support
    // address ranges, it would not make sense to expose the address range as a parameter of this
    // module.
    localparam longint unsigned ADDR_BEGIN  = '0;
    localparam longint unsigned ADDR_END    = {AXI_ADDR_WIDTH{1'b1}};

    AXI_BUS #(
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
        .AXI_ID_WIDTH   (AXI_ID_WIDTH),
        .AXI_USER_WIDTH (AXI_USER_WIDTH)
    ) int_axi();

    axi_riscv_amos #(
        .AXI_ADDR_WIDTH     (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH     (AXI_DATA_WIDTH),
        .AXI_ID_WIDTH       (AXI_ID_WIDTH),
        .AXI_USER_WIDTH     (AXI_USER_WIDTH),
        .AXI_MAX_WRITE_TXNS (AXI_MAX_WRITE_TXNS),
        .RISCV_WORD_WIDTH   (RISCV_WORD_WIDTH)
    ) i_amos (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),
        .slv_port   (slv),
        .mst_port   (int_axi)
    );

    axi_riscv_lrsc #(
        .ADDR_BEGIN     (ADDR_BEGIN),
        .ADDR_END       (ADDR_END),
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .AXI_ID_WIDTH   (AXI_ID_WIDTH)
    ) i_lrsc (
        .clk_i  (clk_i),
        .rst_ni (rst_ni),
        .slv    (int_axi),
        .mst    (mst)
    );

endmodule
