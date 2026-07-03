// SPDX-License-Identifier: MIT

package TestUartRx;

import StmtFSM :: *;
import GetPut :: *;
import TestHelper :: *;

import UartRx :: *;
import TestUart :: *;

(* synthesize *)
module [Module] mkTestUartRx(TestHelper::TestHandler);

    Reg#(Bit#(2))   rg_stop_bits <- mkReg(1);
    Reg#(Bit#(16))  rg_prescaler <- mkReg(11);

    UartRx#(8) dut <- mkUartRx(rg_stop_bits, rg_prescaler);
    Reg#(Bit#(1)) rg_rx <- mkReg(1);
    Reg#(Bool) rg_frame_error <- mkReg(False);
    Reg#(Bool) rg_overflow <- mkReg(False);

    rule rconn;
        dut.rx(rg_rx);
    endrule

    rule rcapture_errors;
        if(dut.frame_error)
            rg_frame_error <= True;
        if(dut.ovflw_error)
            rg_overflow <= True;
    endrule

    Stmt s = seq
        delay(10);
        drive_uart_frame(11, rg_rx, 8'h55);
        action
            let received <- dut.receive.get();
            if(received != 8'h55) begin
                $display("ERROR TestUartRx: expected 55, received %02h", received);
                $finish;
            end
        endaction
        delay(20);
        action
            if(dut.data_valid) begin
                $display("ERROR TestUartRx: duplicate byte was queued");
                $finish;
            end
        endaction

        drive_uart_frame_with_stop(11, rg_rx, 8'hA6, 0);
        rg_rx <= 1;
        delay(20);
        action
            if(!rg_frame_error) begin
                $display("ERROR TestUartRx: framing error was not reported");
                $finish;
            end
            if(dut.data_valid) begin
                $display("ERROR TestUartRx: malformed frame was queued");
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
