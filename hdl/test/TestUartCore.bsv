// SPDX-License-Identifier: MIT

package TestUartCore;

import FIFOF :: *;
import GetPut :: *;
import StmtFSM :: *;

import TestHelper :: *;
import UartCore :: *;

module mkUartDepthTest#(Integer rx_depth, Integer tx_depth)(TestHandler);
    UartCore_ifc#(8) i_uart <- mkUartCore(True, 1, 11, rx_depth, tx_depth);
    FIFOF#(Bit#(8)) f_received <- mkSizedFIFOF(32);

    Reg#(Bool) rg_accept <- mkReg(True);
    Reg#(UInt#(8)) rg_overflows <- mkReg(0);
    Reg#(UInt#(8)) rg_index <- mkReg(0);

    rule r_loopback;
        i_uart.rx(i_uart.tx);
    endrule

    rule r_receive (rg_accept);
        let data <- i_uart.receive.get;
        f_received.enq(data);
    endrule

    rule r_errors;
        if(i_uart.ovflw_error)
            rg_overflows <= rg_overflows + 1;
        if(i_uart.frame_error) begin
            $display("ERROR TestUartCore depths %0d/%0d: unexpected frame error", rx_depth, tx_depth);
            $finish(1);
        end
    endrule

    function Stmt expect_byte(Bit#(8) expected);
        return seq
            action
                let data = f_received.first;
                f_received.deq;
                if(data != expected) begin
                    $display("ERROR TestUartCore depths %0d/%0d: expected %02h got %02h", rx_depth, tx_depth, expected, data);
                    $finish(1);
                end
            endaction
        endseq;
    endfunction

    Stmt s = seq
        delay(10);
        i_uart.transmit.put(8'h55);
        action
            if(tx_depth == 0 && !i_uart.tx_busy) begin
                $display("ERROR TestUartCore: zero-depth TX accepted another active word");
                $finish(1);
            end
        endaction
        i_uart.transmit.put(8'ha6);
        expect_byte(8'h55);
        expect_byte(8'ha6);
        await(!i_uart.tx_busy && !i_uart.rx_busy);
        delay(5);
        action
            if(rg_overflows != 0 || f_received.notEmpty) begin
                $display("ERROR TestUartCore: loss or duplication without stalls");
                $finish(1);
            end
        endaction

        rg_accept <= False;
        // Fill the RX queue, or the assembly register at depth zero, then overrun it.
        for(rg_index <= 0; rg_index < fromInteger(rx_depth == 0 ? 1 : rx_depth); rg_index <= rg_index + 1)
            i_uart.transmit.put(8'h20 + pack(rg_index));
        await(!i_uart.tx_busy && !i_uart.rx_busy);
        delay(5);
        i_uart.transmit.put(8'hee);
        await(!i_uart.tx_busy && !i_uart.rx_busy);
        delay(5);
        action
            if(rg_overflows != 1) begin
                $display("ERROR TestUartCore depths %0d/%0d: wrong capacity or overflow count %0d", rx_depth, tx_depth, rg_overflows);
                $finish(1);
            end
        endaction

        rg_accept <= True;
        if(rx_depth == 0)
            expect_byte(8'hee);
        else
            for(rg_index <= 0; rg_index < fromInteger(rx_depth); rg_index <= rg_index + 1)
                expect_byte(8'h20 + pack(rg_index));
        i_uart.transmit.put(8'hc3);
        expect_byte(8'hc3);
        await(!i_uart.tx_busy && !i_uart.rx_busy);
        delay(5);
        action
            if(rg_overflows != 1 || f_received.notEmpty) begin
                $display("ERROR TestUartCore: failed recovery after overflow");
                $finish(1);
            end
        endaction
    endseq;

    FSM i_test <- mkFSM(s);
    method go = i_test.start;
    method done = i_test.done;
endmodule

(* synthesize *)
module mkTestUartCore(TestHandler);
    TestHandler i_zero  <- mkUartDepthTest(0, 0);
    TestHandler i_one   <- mkUartDepthTest(1, 1);
    TestHandler i_three <- mkUartDepthTest(3, 3);
    TestHandler i_large <- mkUartDepthTest(16, 16);
    TestHandler i_rx    <- mkUartDepthTest(3, 0);
    TestHandler i_tx    <- mkUartDepthTest(0, 3);

    Reg#(UInt#(16)) rg_cycles <- mkReg(0);
    rule r_watchdog;
        rg_cycles <= rg_cycles + 1;
        if(rg_cycles == 20000) begin
            $display("ERROR TestUartCore: timeout");
            $finish(1);
        end
    endrule

    Stmt s = seq
        action
            i_zero.go;
            i_one.go;
            i_three.go;
            i_large.go;
            i_rx.go;
            i_tx.go;
        endaction
        await(i_zero.done && i_one.done && i_three.done && i_large.done && i_rx.done && i_tx.done);
        $display("All tests finished successfully");
    endseq;
    FSM i_test <- mkFSM(s);
    method go = i_test.start;
    method done = i_test.done;
endmodule

endpackage
