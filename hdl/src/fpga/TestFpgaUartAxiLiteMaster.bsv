// SPDX-License-Identifier: MIT

package TestFpgaUartAxiLiteMaster;

import UartAxiLiteMaster :: *;
import BlueCSR :: *;
import Clocks :: *;
import Connectable :: *;
import FIFOF :: *;
import GetPut :: *;
import RegFile :: *;
import STARTUPE2 :: *;

interface DummyUartAxiLiteCsrs;
    method Bool ctrl_en;
    method Bool loop_valid;
endinterface

module [BlueCSRCtx_t#(32, 32)] dummy_uart_axi_lite_csrs(DummyUartAxiLiteCsrs);

    Reg#(Bool)      rg_ctrl_en;
    Reg#(Bit#(4))   rg_ctrl_mode;
    Reg#(Bit#(16))  rg_ctrl_scratch;

    Reg#(Bool)      rg_loop_valid;
    Reg#(Bool)      rg_loop_ready;

    FIFOF#(Bit#(32)) f_loop <- mkSizedFIFOF(16);
    RegFile#(Bit#(4), Bit#(32)) rf_regs <- mkRegFileFull;

    function Bit#(32) read_regfile(Bit#(32) local_addr);
        return rf_regs.sub(truncate(local_addr[5:2]));
    endfunction

    function Action write_regfile(Bit#(32) local_addr, Bit#(32) data);
        action
            rf_regs.upd(truncate(local_addr[5:2]), data);
        endaction
    endfunction

    csr_regmap_def("UartAxiLiteDummy", "UART AXI-lite master dummy CSR target");

    csr_reg_def('h00, "MIV", "Module ID and Version Register");
    csr_reg_rc('h00, Bit#(16)'('hA711),  0, "MID", "Module ID", "Dummy UART AXI-lite target ID.");
    csr_reg_rc('h00, Bit#(8)'('h01),    16, "VRS", "Module Version", "Dummy UART AXI-lite target version.");

    csr_reg_def('h04, "CTRL", "Control and scratch register");
    rg_ctrl_en      <- csr_reg_rw('h04, False, 0,  "EN",      "Enable",  "Read/write enable bit.");
    rg_ctrl_mode    <- csr_reg_rw('h04, 4'h1,  4,  "MODE",    "Mode",    "Read/write mode field.");
    rg_ctrl_scratch <- csr_reg_rw('h04, 16'h0, 16, "SCRATCH", "Scratch", "Read/write scratch field.");

    csr_reg_def('h08, "STATUS", "Read-only status register");
    rg_loop_valid <- csr_reg_ro('h08, False, 0, "LOOPVALID", "Loopback FIFO Valid", "The loopback FIFO has readable data.");
    rg_loop_ready <- csr_reg_ro('h08, True,  1, "LOOPREADY", "Loopback FIFO Ready", "The loopback FIFO can accept a write.");
    csr_reg_rc('h08, Bit#(8)'('h5A), 8, "CONST", "Constant Status", "Fixed read-only status field.");

    rule rloop_status;
        rg_loop_valid <= f_loop.notEmpty;
        rg_loop_ready <= f_loop.notFull;
    endrule

    csr_reg_def('h0C, "LOOP_WO", "Write-only loopback FIFO register");
    csr_reg_fifo_wo('h0C, f_loop, "DATA", "Loopback Write Data", "Writes a word into the loopback FIFO.");

    csr_reg_def('h10, "LOOP_RO", "Read-only loopback FIFO register");
    csr_reg_fifo_ro('h10, f_loop, "DATA", "Loopback Read Data", "Reads and dequeues a word from the loopback FIFO.");

    csr_region_rw('h100, 64, read_regfile, write_regfile, "REGFILE", "Sixteen 32-bit dummy register-file words.");

    method ctrl_en = rg_ctrl_en;
    method loop_valid = rg_loop_valid;
endmodule

(* always_enabled *)
interface UartAxiLiteMasterFpga;
    (* prefix="" *)
    method Action rxd((* port="uart_rxd" *) Bit#(1) value);

    (* result="uart_txd" *)
    method Bit#(1) txd();

    (* result="led" *)
    method Bit#(2) led();
endinterface

(* synthesize, default_clock_osc="clk_12", no_default_reset *)
module mkUartAxiLiteMasterFpga(UartAxiLiteMasterFpga);

    Reset rst <- mkSTARTUPE2EOSReset;

    UartAxiLiteMaster#(32, 32) bridge <- mkUartAxiLiteMaster(1, 104, 2, 2, reset_by rst);
    BlueCSRAccess_ifc#(32, 32, DummyUartAxiLiteCsrs) csrs <- create_blue_csr(dummy_uart_axi_lite_csrs, False, reset_by rst);
    BlueCSR_AXI4Lite_ifc#(32, 32) axi_csrs <- mkBlueCSRAXI4LiteAdapter(csrs.external, 1, 1, reset_by rst);

    mkConnection(bridge.m_rd, axi_csrs.s_rd);
    mkConnection(bridge.m_wr, axi_csrs.s_wr);

    method Action rxd(Bit#(1) value);
        bridge.rx(value);
    endmethod

    method Bit#(1) txd = bridge.tx();
    method Bit#(2) led = {pack(csrs.internal.loop_valid), pack(csrs.internal.ctrl_en)};

endmodule

endpackage
