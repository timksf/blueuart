// SPDX-License-Identifier: MIT

package UartCsr;

import GetPut :: *;

import BlueCSRCore :: *;
import BlueCSRAXI4LiteAdapter :: *;
import AXI4_Lite_Slave :: *;

import UartCore :: *;
import UartRegs :: *;

interface UartCsr_ifc;
    (* always_enabled, prefix="uart" *) method Action rx(Bit#(1) value);
    (* always_ready, result="uart_tx" *) method Bit#(1) tx;

    method Bool rx_busy;
    method Bool tx_busy;

    (* prefix="S_AXI_cfg" *) interface AXI4_Lite_Slave_Rd_Fab#(32, 32) s_rd;
    (* prefix="S_AXI_cfg" *) interface AXI4_Lite_Slave_Wr_Fab#(32, 32) s_wr;
endinterface

module [Module] mkUartCsr#(Integer rx_depth, Integer tx_depth)(UartCsr_ifc);
    BlueCSRAccess_ifc#(32, 32, 0, UartRegs_ifc) i_csrs <-
        create_blue_csr(uart_csrs(rx_depth, tx_depth), False);
    BlueCSR_AXI4Lite_ifc#(32, 32, 0) i_axi <- mkBlueCSRAXI4LiteAdapter(i_csrs.external, 1, 1);

    Bit#(2) stop_bits = i_csrs.internal.control.ctrl_s2 ? 2 : 1;
    UartCore_ifc#(8) i_uart <- mkUartCore(
        i_csrs.internal.control.ctrl_en, stop_bits,
        i_csrs.internal.control.prescaler, 0, 0);

    // RX completion rules produce error pulses. Keep their collection separate
    // from busy/valid reads to avoid a rule-ordering cycle.
    rule r_errors;
        i_csrs.internal.control.frame_error(i_uart.frame_error);
        i_csrs.internal.control.ovflw_error(i_uart.ovflw_error);
    endrule

    rule r_status;
        i_csrs.internal.control.tx_busy(i_uart.tx_busy || i_csrs.internal.tx_data_valid);
        i_csrs.internal.control.rx_busy(i_uart.rx_busy);
        i_csrs.internal.control.tx_ready(i_csrs.internal.tx_data_ready);
        i_csrs.internal.control.rx_valid(i_csrs.internal.rx_data_valid);
    endrule

    rule r_transmit;
        i_uart.transmit.put(i_csrs.internal.tx_data_first);
        i_csrs.internal.tx_data_deq;
    endrule

    rule r_receive;
        let data <- i_uart.receive.get;
        i_csrs.internal.rx_data_enq(data);
    endrule

    method rx      = i_uart.rx;
    method tx      = i_uart.tx;
    method rx_busy = i_uart.rx_busy;
    method tx_busy = i_uart.tx_busy || i_csrs.internal.tx_data_valid;

    interface s_rd = i_axi.s_rd;
    interface s_wr = i_axi.s_wr;
endmodule

endpackage
