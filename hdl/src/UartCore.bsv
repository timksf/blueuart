// SPDX-License-Identifier: MIT

package UartCore;

import GetPut :: *;

import UartRx :: *;
import UartTx :: *;

interface UartCore_ifc#(numeric type n);
    (* always_enabled, prefix="uart" *) method Action rx(Bit#(1) value);
    (* always_ready, result="uart_tx" *) method Bit#(1) tx;

    method Bool rx_busy;
    method Bool tx_busy;
    method Bool frame_error;
    method Bool ovflw_error;

    interface Get#(Bit#(n)) receive;
    interface Put#(Bit#(n)) transmit;
endinterface

module mkUartCore#(
        Bool enable, Bit#(2) stop_bits, Bit#(16) prescaler,
        Integer rx_depth, Integer tx_depth
    )(UartCore_ifc#(n))
    provisos(
        Log#(n, ln),
        Add#(ln, 1, n1),
        Add#(a__, 1, n)
    );

    UartRx#(n) i_rx <- mkUartRx(stop_bits, prescaler, rx_depth);
    UartTx#(n) i_tx <- mkUartTx(stop_bits, prescaler, tx_depth);

    method Action rx(Bit#(1) value);
        i_rx.rx(enable ? value : 1);
    endmethod

    method tx          = i_tx.tx;
    method rx_busy     = i_rx.busy;
    method tx_busy     = i_tx.busy;
    method frame_error = i_rx.frame_error;
    method ovflw_error = i_rx.ovflw_error;

    interface receive = i_rx.receive;
    interface Put transmit;
        method Action put(Bit#(n) data) if(enable);
            i_tx.transmit.put(data);
        endmethod
    endinterface
endmodule

endpackage
