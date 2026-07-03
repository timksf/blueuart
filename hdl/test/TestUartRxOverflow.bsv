// SPDX-License-Identifier: MIT

package TestUartRxOverflow;

import StmtFSM :: *;
import TestHelper :: *;

import UartRx :: *;
import TestUart :: *;

(* synthesize *)
module [Module] mkTestUartRxOverflow(TestHelper::TestHandler);

    Reg#(Bit#(2)) rg_stop_bits <- mkReg(1);
    Reg#(Bit#(16)) rg_prescaler <- mkReg(11);
    Reg#(Bit#(1)) rg_rx <- mkReg(1);
    Reg#(Bool) rg_overflow <- mkReg(False);

    UartRx#(8) dut <- mkUartRx(rg_stop_bits, rg_prescaler);

    rule rconn;
        dut.rx(rg_rx);
    endrule

    rule rcapture_overflow if(dut.ovflw_error);
        rg_overflow <= True;
    endrule

    Stmt s = seq
        delay(10);
        drive_uart_frame(11, rg_rx, 8'h56);
        drive_uart_frame(11, rg_rx, 8'h78);
        drive_uart_frame(11, rg_rx, 8'h9A);
        delay(20);
        action
            if(!rg_overflow) begin
                $display("ERROR TestUartRxOverflow: FIFO overflow was not reported");
                $finish;
            end
        endaction
        $display("All tests finished successfully");
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
