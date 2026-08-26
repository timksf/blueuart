// SPDX-License-Identifier: MIT

package UartCore;

import GetPut :: *;

import BlueCSR :: *;
import BlueAXI :: *;

import UartRegs :: *;
import UartRx :: *;
import UartTx :: *;

interface UartCore;

    (*always_ready*) method Bool rx_busy;
    (*always_ready*) method Bool tx_busy;

    (*always_enabled*) (*prefix="uart"*) interface WriteOnly#(Bit#(1))  rx;
    (*always_enabled*) (*prefix="uart"*) interface ReadOnly#(Bit#(1))   tx;

    (*prefix="S_AXI_cfg"*) interface AXI4_Lite_Slave_Rd_Fab#(32, 32) s_rd;
    (*prefix="S_AXI_cfg"*) interface AXI4_Lite_Slave_Wr_Fab#(32, 32) s_wr;

    interface Get#(Bit#(8)) receive;
    interface Put#(Bit#(8)) transmit;

endinterface

module [Module] mkUartCore#(Integer rx_buffer, Integer tx_buffer, Bool csr_fifos)(UartCore);

    BlueCSRAccess_ifc#(32, 32, 0, UartRegs) csrs        <- create_blue_csr(uart_csrs(csr_fifos), False);
    BlueCSR_AXI4Lite_ifc#(32, 32)           axi_csrs    <- mkBlueCSRAXI4LiteAdapter(csrs.external, 1, 1);

    Bit#(2) stop_bits = csrs.internal.ctrl_s2 ? 2 : 1;

    UartTx#(8) uart_tx <- mkUartTxBuffered(stop_bits, csrs.internal.prescaler, tx_buffer);
    UartRx#(8) uart_rx <- mkUartRxBuffered(stop_bits, csrs.internal.prescaler, rx_buffer);

    rule rerrors;
        csrs.internal.frame_error(uart_rx.frame_error);
        csrs.internal.ovflw_error(uart_rx.ovflw_error);
    endrule

    rule rstatus;
        csrs.internal.tx_busy(uart_tx.busy);
        csrs.internal.rx_busy(uart_rx.busy);
        csrs.internal.tx_ready(csrs.internal.tx_data_ready);
        csrs.internal.rx_valid(csrs.internal.rx_data_valid);
    endrule

    rule rtransmit if(csr_fifos && csrs.internal.ctrl_en && csrs.internal.tx_data_valid);
        uart_tx.transmit.put(csrs.internal.tx_data_first);
        csrs.internal.tx_data_deq;
    endrule

    rule rreceive if(csr_fifos && csrs.internal.rx_data_ready);
        let data <- uart_rx.receive.get;
        csrs.internal.rx_data_enq(data);
    endrule

    method rx_busy = uart_rx.busy;
    method tx_busy = uart_tx.busy;

    interface WriteOnly rx;
        method Action _write(Bit#(1) value);
            uart_rx.rx(csrs.internal.ctrl_en ? value : 1);
        endmethod
    endinterface
    interface ReadOnly tx;
        method Bit#(1) _read = uart_tx.tx;
    endinterface
    interface s_rd      = axi_csrs.s_rd;
    interface s_wr      = axi_csrs.s_wr;
    interface receive   = uart_rx.receive;
    interface transmit  = uart_tx.transmit;

endmodule

endpackage
