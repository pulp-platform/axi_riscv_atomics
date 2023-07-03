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

// Wrapper for the AXI RISC-V Atomics Adapter that exposes AXI SystemVerilog structs.
//
// See the header of `axi_riscv_atomics` for a description.
//
// Author: Paul Scheffler <paulsc@iis.ee.ethz.ch>
// Maintainer: Andreas Kurth <akurth@iis.ee.ethz.ch>

`include "axi/assign.svh"

module axi_riscv_atomics_structs #(
  parameter int unsigned  AxiAddrWidth    = 0,
  parameter int unsigned  AxiDataWidth    = 0,
  parameter int unsigned  AxiIdWidth      = 0,
  parameter int unsigned  AxiUserWidth    = 0,
  parameter int unsigned  AxiMaxReadTxns  = 0,
  parameter int unsigned  AxiMaxWriteTxns = 0,
  parameter int unsigned  AxiUserAsId     = 0,
  parameter int unsigned  AxiUserIdMsb    = 0,
  parameter int unsigned  AxiUserIdLsb    = 0,
  parameter int unsigned  RiscvWordWidth  = 0,
  parameter int unsigned  NAxiCuts        = 0,
  parameter int unsigned  AxiAddrLSB      = $clog2(AxiDataWidth/8),
  parameter type          axi_req_t       = logic,
  parameter type          axi_rsp_t       = logic
) (
  input  logic      clk_i,
  input  logic      rst_ni,
  input  axi_req_t  axi_slv_req_i,
  output axi_rsp_t  axi_slv_rsp_o,
  output axi_req_t  axi_mst_req_o,
  input  axi_rsp_t  axi_mst_rsp_i
);

  AXI_BUS #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth ),
    .AXI_DATA_WIDTH ( AxiDataWidth ),
    .AXI_ID_WIDTH   ( AxiIdWidth   ),
    .AXI_USER_WIDTH ( AxiUserWidth )
  ) slv ();

  `AXI_ASSIGN_FROM_REQ(slv, axi_slv_req_i)
  `AXI_ASSIGN_TO_RESP(axi_slv_rsp_o, slv)

  AXI_BUS #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth ),
    .AXI_DATA_WIDTH ( AxiDataWidth ),
    .AXI_ID_WIDTH   ( AxiIdWidth   ),
    .AXI_USER_WIDTH ( AxiUserWidth )
  ) mst ();

  `AXI_ASSIGN_TO_REQ(axi_mst_req_o, mst)
  `AXI_ASSIGN_FROM_RESP(mst, axi_mst_rsp_i)

  axi_riscv_atomics_wrap #(
    .AXI_ADDR_WIDTH     ( AxiAddrWidth    ),
    .AXI_DATA_WIDTH     ( AxiDataWidth    ),
    .AXI_ID_WIDTH       ( AxiIdWidth      ),
    .AXI_USER_WIDTH     ( AxiUserWidth    ),
    .AXI_MAX_READ_TXNS  ( AxiMaxReadTxns  ),
    .AXI_MAX_WRITE_TXNS ( AxiMaxWriteTxns ),
    .AXI_USER_AS_ID     ( AxiUserAsId     ),
    .AXI_USER_ID_MSB    ( AxiUserIdMsb    ),
    .AXI_USER_ID_LSB    ( AxiUserIdLsb    ),
    .AXI_ADDR_LSB       ( AxiAddrLSB      ),
    .RISCV_WORD_WIDTH   ( RiscvWordWidth  ),
    .N_AXI_CUT          ( NAxiCuts        )
  ) i_axi_riscv_atomics_wrap (
    .clk_i,
    .rst_ni,
    .mst,
    .slv
  );

endmodule
