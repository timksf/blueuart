// SPDX-License-Identifier: MIT

package TestUartTx;

import StmtFSM :: *;
import GetPut :: *;
import TestHelper :: *;

import UartTx :: *;
import TestUart :: *;

(* synthesize *)
module [Module] mkTestUartTx(TestHelper::TestHandler);

    Reg#(Bit#(2))  rg_stop_bits <- mkReg(1);
    Reg#(Bit#(16)) rg_prescaler <- mkReg(11);

    UartTx#(8) dut <- mkUartTx(rg_stop_bits, rg_prescaler);

    function Bit#(1) tx_line() = dut.tx();

    Stmt s = seq
        delay(10);
        dut.transmit.put(8'h55);
        expect_uart_Xn1(11, tx_line, 8'h55);
        dut.transmit.put(8'hA6);
        expect_uart_Xn1(11, tx_line, 8'hA6);
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
