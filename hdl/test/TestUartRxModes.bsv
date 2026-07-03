// SPDX-License-Identifier: MIT

package TestUartRxModes;

import StmtFSM :: *;
import GetPut :: *;
import TestHelper :: *;

import UartRx :: *;
import TestUart :: *;

(* synthesize *)
module [Module] mkTestUartRxModes(TestHelper::TestHandler);

    Reg#(Bit#(2))   rg_stop_bits    <- mkReg(1);
    Reg#(Bit#(16))  rg_prescaler    <- mkReg(11);
    Reg#(Bit#(1))   rg_rx           <- mkReg(1);

    UartRx#(8) dut <- mkUartRx(rg_stop_bits, rg_prescaler);

    rule rconn;
        dut.rx(rg_rx);
    endrule

    Stmt s = seq
        delay(10);
        rg_stop_bits <= 2;
        drive_uart_frame(11, rg_rx, 8'h3C);
        delay(11);
        action
            let received <- dut.receive.get();
            if(received != 8'h3C) begin
                $display("ERROR TestUartRxModes: two-stop frame expected 3C, received %02h", received);
                $finish;
            end
        endaction

        rg_stop_bits <= 1;
        drive_uart_frame(11, rg_rx, 8'h12);
        drive_uart_frame(11, rg_rx, 8'h34);
        action
            let received <- dut.receive.get();
            if(received != 8'h12) begin
                $display("ERROR TestUartRxModes: first byte expected 12, received %02h", received);
                $finish;
            end
        endaction
        action
            let received <- dut.receive.get();
            if(received != 8'h34) begin
                $display("ERROR TestUartRxModes: second byte expected 34, received %02h", received);
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
