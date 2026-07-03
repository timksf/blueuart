// SPDX-License-Identifier: MIT

package TestFpgaUartLoopback;

import GetPut :: *;
import Clocks :: *;
import FIFOF :: *;

import UartRx :: *;
import UartTx :: *;
import STARTUPE2 :: *;

(* always_enabled *)
interface UartLoopback;
    (* prefix="" *)
    method Action rxd((* port="uart_rxd" *) Bit#(1) value);

    (* result="uart_txd" *)
    method Bit#(1) uart_txd();

    (* result="led" *)
    method Bit#(2) led();
endinterface

(* synthesize, default_clock_osc="clk_12", no_default_reset *)
module mkUartLoopback(UartLoopback);

    Bit#(2)  stop_bits = 1;
    Bit#(16) prescaler = 104;

    Reset rst <- mkSTARTUPE2EOSReset;

    UartRx#(8) uart_rx     <- mkUartRx(stop_bits, prescaler, reset_by rst);
    UartTx#(8) uart_tx     <- mkUartTx(stop_bits, prescaler, reset_by rst);
    FIFOF#(Bit#(8)) loopback_fifo   <- mkSizedFIFOF(16, reset_by rst);

    rule rcapture;
        let data <- uart_rx.receive.get();
        loopback_fifo.enq(data);
    endrule

    rule rtransmit;
        uart_tx.transmit.put(loopback_fifo.first);
        loopback_fifo.deq();
    endrule

    method Action rxd(Bit#(1) value);
        uart_rx.rx(value);
    endmethod

    method Bit#(1) uart_txd = uart_tx.tx;
    method Bit#(2) led = {pack(uart_rx.busy), pack(uart_tx.busy)};

endmodule

endpackage
