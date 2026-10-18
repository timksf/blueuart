// SPDX-License-Identifier: MIT

package TestUartRxHold;

import GetPut :: *;
import StmtFSM :: *;

import TestHelper :: *;
import TestUart :: *;
import UartRx :: *;

module mkUartRxHoldCase#(Integer test_case)(TestHandler);
    UartRx#(8) i_uart <- mkUartRx(1, 11, 0);
    Reg#(Bit#(1)) rg_rx <- mkReg(1);
    Reg#(UInt#(8)) rg_index <- mkReg(0);
    Reg#(UInt#(8)) rg_overflows <- mkReg(0);
    Reg#(UInt#(8)) rg_frame_errors <- mkReg(0);

    rule r_connect;
        i_uart.rx(rg_rx);
    endrule

    rule r_errors;
        if(i_uart.ovflw_error)
            rg_overflows <= rg_overflows + 1;
        if(i_uart.frame_error)
            rg_frame_errors <= rg_frame_errors + 1;
    endrule

    function Stmt expect_byte(Bit#(8) expected);
        return seq
            action
                let data <- i_uart.receive.get;
                if(data != expected) begin
                    $display("ERROR TestUartRxHold case %0d: expected %02h got %02h", test_case, expected, data);
                    $finish(1);
                end
            endaction
        endseq;
    endfunction

    function Action check_errors(UInt#(8) overflows, UInt#(8) frame_errors);
        return action
            if(rg_overflows != overflows || rg_frame_errors != frame_errors) begin
                $display("ERROR TestUartRxHold case %0d: expected overflow/frame %0d/%0d got %0d/%0d",
                    test_case, overflows, frame_errors, rg_overflows, rg_frame_errors);
                $finish(1);
            end
        endaction;
    endfunction

    Stmt s = seq
        delay(10);
        if(test_case == 0) seq
            drive_uart_frame(11, rg_rx, 8'h12);
            delay(100);
            check_errors(0, 0);
            expect_byte(8'h12);
            // Unread words are replaced; only the most recent word remains.
            for(rg_index <= 0; rg_index < 3; rg_index <= rg_index + 1)
                drive_uart_frame(11, rg_rx, 8'h40 + pack(rg_index));
            delay(100);
            check_errors(2, 0);
            expect_byte(8'h42);
        endseq
        else if(test_case == 1) seq
            // A get offered before reception must wait for a completed word.
            par
                drive_uart_frame(11, rg_rx, 8'hc3);
                expect_byte(8'hc3);
            endpar
            drive_uart_frame(11, rg_rx, 8'h5a);
            rg_rx <= 0;
            delay(1);
            rg_rx <= 1;
            delay(20);
            check_errors(0, 0);
            expect_byte(8'h5a);

            drive_uart_frame(11, rg_rx, 8'h31);
            // Two synchronizer stages and the mid-start sample put confirmation
            // nine clocks after the driven falling edge. Consume on that edge.
            rg_rx <= 0;
            delay(8);
            expect_byte(8'h31);
            delay(1);
            drive_uart_data_bits_with_stop(11, rg_rx, 8'h7e, 1, 0);
            delay(20);
            expect_byte(8'h7e);
            check_errors(0, 0);
        endseq
        else seq
            drive_uart_frame(11, rg_rx, 8'h11);
            // A new frame retires the old word even if that new frame is malformed.
            drive_uart_frame_with_stop(11, rg_rx, 8'ha6, 0);
            rg_rx <= 1;
            delay(20);
            check_errors(1, 1);
            drive_uart_frame(11, rg_rx, 8'h77);
            delay(20);
            expect_byte(8'h77);
            check_errors(1, 1);
        endseq
    endseq;
    FSM i_test <- mkFSM(s);
    method go = i_test.start;
    method done = i_test.done;
endmodule

(* synthesize *)
module mkTestUartRxHold(TestHandler);
    TestHandler i_idle <- mkUartRxHoldCase(0);
    TestHandler i_boundary <- mkUartRxHoldCase(1);
    TestHandler i_error <- mkUartRxHoldCase(2);
    Reg#(UInt#(16)) rg_cycles <- mkReg(0);
    rule r_watchdog;
        rg_cycles <= rg_cycles + 1;
        if(rg_cycles == 10000) begin
            $display("ERROR TestUartRxHold: timeout");
            $finish(1);
        end
    endrule
    Stmt s = seq
        action
            i_idle.go;
            i_boundary.go;
            i_error.go;
        endaction
        await(i_idle.done && i_boundary.done && i_error.done);
        $display("All tests finished successfully");
    endseq;
    FSM i_test <- mkFSM(s);
    method go = i_test.start;
    method done = i_test.done;
endmodule

endpackage
