// SPDX-License-Identifier: MIT

package TestUartAxisBridgeCsr;

import AXI4_Lite_Master :: *;
import AXI4_Lite_Types :: *;
import AXI4_Stream :: *;
import UartAxisBridge :: *;
import Connectable :: *;
import GetPut :: *;
import StmtFSM :: *;

import TestHelper :: *;
import TestUart :: *;

function Stmt axi_write(AXI4_Lite_Master_Wr#(32, 32) master, Bit#(32) addr, Bit#(32) data);
    return seq
        action
            master.request.put(AXI4_Lite_Write_Rq_Pkg {
                addr: addr,
                data: data,
                strb: '1,
                prot: UNPRIV_SECURE_DATA
            });
        endaction
        action
            let rsp <- master.response.get();
            if(rsp.resp != OKAY) begin
                $display("ERROR TestUartAxisBridgeCsr: write %08x got response %0d", addr, pack(rsp.resp));
                $finish(1);
            end
        endaction
    endseq;
endfunction

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
module [Module] mkTestUartAxisBridgeCsr(TestHandler);

    UartAxisBridgeCsr#(8, 1) dut <- mkUartAxisBridgeCsr(2, 2);
    AXI4_Stream_Rd#(8, 1) axis_sink <- mkAXI4_Stream_Rd(2);
    AXI4_Stream_Wr#(8, 1) axis_source <- mkAXI4_Stream_Wr(2);
    AXI4_Lite_Master_Wr#(32, 32) cfg_wr <- mkAXI4_Lite_Master_Wr(2);
    AXI4_Lite_Master_Rd#(32, 32) cfg_rd <- mkAXI4_Lite_Master_Rd(2);

    mkConnection(dut.m_axis, axis_sink.fab);
    mkConnection(axis_source.fab, dut.s_axis);
    mkConnection(cfg_wr.fab, dut.s_wr);
    mkConnection(cfg_rd.fab, dut.s_rd);

    Reg#(Bit#(1)) rg_rx <- mkReg(1);

    rule rconn;
        dut.rx(rg_rx);
    endrule

    function Bit#(1) tx_line() = dut.tx();

    Stmt s = seq
        delay(5);

        axi_write(cfg_wr, 'h08, 11);
        axi_write(cfg_wr, 'h04, 1);

        drive_uart_frame(11, rg_rx, 8'hc3);
        action
            let p <- axis_sink.pkg.get();
            if(p.data != 8'hc3 || !p.last || p.keep != '1) begin
                $display("ERROR TestUartAxisBridgeCsr: expected AXIS data=c3 last=1 keep=1, got data=%02h last=%0d keep=%0h", p.data, pack(p.last), p.keep);
                $finish(1);
            end
        endaction

        axis_source.pkg.put(axis_byte(8'h7e, True));
        expect_uart_Xn1(11, tx_line, 8'h7e);

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
