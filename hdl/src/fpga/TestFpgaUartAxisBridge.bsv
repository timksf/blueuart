// SPDX-License-Identifier: MIT

package TestFpgaUartAxisBridge;

import UartAxisBridge :: *;
import Clocks :: *;
import Connectable :: *;
import STARTUPE2 :: *;

(* always_enabled *)
interface UartAxisBridgeLoopback;
    (* prefix="" *)
    method Action rxd((* port="uart_rxd" *) Bit#(1) value);

    (* result="uart_txd" *)
    method Bit#(1) txd();

    (* result="led" *)
    method Bit#(2) led();
endinterface

(* synthesize, default_clock_osc="clk_12", no_default_reset *)
module mkUartAxisBridgeLoopback(UartAxisBridgeLoopback);

    Reset rst <- mkSTARTUPE2EOSReset;

    UartAxisBridge#(8, 1) bridge <- mkUartAxisBridge(1, 104, 16, 16, reset_by rst);

    mkConnection(bridge.m_axis, bridge.s_axis);

    method Action rxd(Bit#(1) value);
        bridge.rx(value);
    endmethod

    method Bit#(1) txd = bridge.tx();
    method Bit#(2) led = {pack(bridge.tx_busy), pack(bridge.rx_busy)};

endmodule

endpackage
