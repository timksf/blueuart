// SPDX-License-Identifier: MIT

package TestFpgaUartCoreLoopback;

import Clocks :: *;
import Connectable :: *;
import FIFOF :: *;
import GetPut :: *;
import StmtFSM :: *;

import AXI4_Lite_Master :: *;
import AXI4_Lite_Types :: *;
import BlueUART :: *;
import STARTUPE2 :: *;

(* always_enabled *)
interface UartCoreLoopback;
    (* prefix="" *)
    method Action rxd((* port="uart_rxd" *) Bit#(1) value);

    (* result="uart_txd" *)
    method Bit#(1) txd();

    (* result="led" *)
    method Bit#(2) led();
endinterface

(* synthesize, default_clock_osc="clk_12", no_default_reset *)
module mkUartCoreLoopback(UartCoreLoopback);

    Reset rst <- mkSTARTUPE2EOSReset;

    UartCore uart <- mkUartCore(2, 2, True, reset_by rst);

    AXI4_Lite_Master_Wr#(32, 32) m_wr <- mkAXI4_Lite_Master_Wr(2, reset_by rst);
    AXI4_Lite_Master_Rd#(32, 32) m_rd <- mkAXI4_Lite_Master_Rd(2, reset_by rst);

    mkConnection(m_wr.fab, uart.s_wr);
    mkConnection(m_rd.fab, uart.s_rd);

    Reg#(Bool)      rg_config_done      <- mkReg(False, reset_by rst);
    Reg#(Bool)      rg_axi_error        <- mkReg(False, reset_by rst);
    FIFOF#(Bit#(8)) f_loopback          <- mkSizedFIFOF(16, reset_by rst);

    Stmt configure = seq
        delay(4);

        action
            m_wr.request.put(AXI4_Lite_Write_Rq_Pkg {
                addr: 'h08,
                data: 104,
                strb: '1,
                prot: UNPRIV_SECURE_DATA
            });
        endaction
        action
            let rsp <- m_wr.response.get();
            if(rsp.resp != OKAY) rg_axi_error <= True;
        endaction

        action
            m_wr.request.put(AXI4_Lite_Write_Rq_Pkg {
                addr: 'h04,
                data: 'h01,
                strb: '1,
                prot: UNPRIV_SECURE_DATA
            });
        endaction
        action
            let rsp <- m_wr.response.get();
            if(rsp.resp != OKAY) rg_axi_error <= True;
            rg_config_done <= rsp.resp == OKAY && !rg_axi_error;
        endaction
    endseq;

    mkAutoFSM(configure, reset_by rst);

    rule rreceive if(rg_config_done && !rg_axi_error);
        let data <- uart.receive.get();
        f_loopback.enq(data);
    endrule

    rule rtransmit if(rg_config_done && !rg_axi_error);
        uart.transmit.put(f_loopback.first);
        f_loopback.deq();
    endrule

    method Action rxd(Bit#(1) value);
        uart.rx._write(value);
    endmethod

    method Bit#(1) txd = uart.tx._read();
    method Bit#(2) led = {pack(rg_axi_error), pack(rg_config_done)};

endmodule

endpackage
