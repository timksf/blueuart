// SPDX-License-Identifier: MIT

package TestUartLoopback;

import StmtFSM :: *;
import GetPut :: *;
import TestHelper :: *;

import UartRx :: *;
import UartTx :: *;

(* synthesize *)
module [Module] mkTestUartLoopback(TestHelper::TestHandler);

    Reg#(Bit#(2))   rg_stop_bits <- mkReg(1);
    Reg#(Bit#(16))  rg_prescaler <- mkReg(11);

    UartTx#(8) uart_tx <- mkUartTx(rg_stop_bits, rg_prescaler);
    UartRx#(8) uart_rx <- mkUartRx(rg_stop_bits, rg_prescaler);

    rule rloopback;
        uart_rx.rx(uart_tx.tx);
    endrule

    Stmt s = seq
        delay(10);
        uart_tx.transmit.put(8'h55);
        uart_tx.transmit.put(8'hA6);
        action
            let received <- uart_rx.receive.get();
            if(received != 8'h55)
                $display("ERROR TestLoopback: expected 55, received %02h", received);
        endaction
        action
            let received <- uart_rx.receive.get();
            if(received != 8'hA6)
                $display("ERROR TestLoopback: expected A6, received %02h", received);
        endaction
    endseq;

    FSM testFSM <- mkFSM(s);

    method Action go();
        testFSM.start();
    endmethod

    method Bool done();
        return testFSM.done();
    endmethod

endmodule

endpackage
