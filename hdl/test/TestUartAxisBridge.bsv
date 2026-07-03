// SPDX-License-Identifier: MIT

package TestUartAxisBridge;

import AXI4_Stream :: *;
import UartAxisBridge :: *;
import Connectable :: *;
import GetPut :: *;
import StmtFSM :: *;

import TestHelper :: *;
import TestUart :: *;

function AXI4_Stream_Pkg#(8, 1) axis_byte(Bit#(8) data, Bool last);
    return AXI4_Stream_Pkg {
        data: data,
        user: 0,
        keep: '1,
        dest: 0,
        id:   0,
        last: last
    };
endfunction

(* synthesize *)
module [Module] mkTestUartAxisBridge(TestHandler);

    UartAxisBridge#(8, 1) dut <- mkUartAxisBridge(1, 11, 2, 2);
    AXI4_Stream_Rd#(8, 1) axis_sink <- mkAXI4_Stream_Rd(2);
    AXI4_Stream_Wr#(8, 1) axis_source <- mkAXI4_Stream_Wr(2);

    mkConnection(dut.m_axis, axis_sink.fab);
    mkConnection(axis_source.fab, dut.s_axis);

    Reg#(Bit#(1)) rg_rx <- mkReg(1);

    rule rconn;
        dut.rx(rg_rx);
    endrule

    function Bit#(1) tx_line() = dut.tx();

    Stmt s = seq
        delay(5);

        drive_uart_frame(11, rg_rx, 8'h5a);
        action
            let p <- axis_sink.pkg.get();
            if(p.data != 8'h5a || !p.last || p.keep != '1) begin
                $display("ERROR TestUartAxisBridge: expected AXIS data=5a last=1 keep=1, got data=%02h last=%0d keep=%0h", p.data, pack(p.last), p.keep);
                $finish(1);
            end
        endaction

        axis_source.pkg.put(axis_byte(8'ha6, True));
        expect_uart_Xn1(11, tx_line, 8'ha6);

        axis_source.pkg.put(axis_byte(8'h3c, False));
        expect_uart_Xn1(11, tx_line, 8'h3c);

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
