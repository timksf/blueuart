// SPDX-License-Identifier: MIT

package TestUartCore;

import Connectable :: *;
import GetPut :: *;
import StmtFSM :: *;

import AXI4_Lite_Master :: *;
import AXI4_Lite_Types :: *;
import BlueUART :: *;
import TestHelper :: *;
import TestUart :: *;

function Stmt axi_write(AXI4_Lite_Master_Wr#(32, 32) master, Bit#(32) addr, Bit#(32) data,Bit#(4) strb, AXI4_Lite_Response expected_resp);
    return seq
        action
            master.request.put(AXI4_Lite_Write_Rq_Pkg {
                addr: addr,
                data: data,
                strb: strb,
                prot: UNPRIV_SECURE_DATA
            });
        endaction
        action
            let rsp <- master.response.get();
            if(rsp.resp != expected_resp) begin
                $display(
                    "ERROR TestUartRegs: write %08x expected response %0d, got %0d",
                    addr,
                    pack(expected_resp),
                    pack(rsp.resp)
                );
                $finish(1);
            end
        endaction
    endseq;
endfunction

function Stmt expect_axi_read_masked(AXI4_Lite_Master_Rd#(32, 32) master, Bit#(32) addr, Bit#(32) expected_data, Bit#(32) mask, AXI4_Lite_Response expected_resp);
    return seq
        action
            master.request.put(AXI4_Lite_Read_Rq_Pkg {
                addr: addr,
                prot: UNPRIV_SECURE_DATA
            });
        endaction
        action
            let rsp <- master.response.get();
            if(rsp.resp != expected_resp || (rsp.data & mask) != (expected_data & mask)) begin
                $display(
                    "ERROR TestUartRegs: read %08x expected data %08x mask %08x response %0d, got data %08x response %0d",
                    addr,
                    expected_data,
                    mask,
                    pack(expected_resp),
                    rsp.data,
                    pack(rsp.resp)
                );
                $finish(1);
            end
        endaction
    endseq;
endfunction

function Stmt expect_axi_read(AXI4_Lite_Master_Rd#(32, 32) master, Bit#(32) addr, Bit#(32) expected_data, AXI4_Lite_Response expected_resp);
    return expect_axi_read_masked(master, addr, expected_data, '1, expected_resp);
endfunction

(* synthesize *)
module [Module] mkTestUartCore(TestHelper::TestHandler);

    UartCore dut <- mkUartCore(2, 2, True);

    AXI4_Lite_Master_Wr#(32, 32) m_wr <- mkAXI4_Lite_Master_Wr(2);
    AXI4_Lite_Master_Rd#(32, 32) m_rd <- mkAXI4_Lite_Master_Rd(2);

    mkConnection(m_wr.fab, dut.s_wr);
    mkConnection(m_rd.fab, dut.s_rd);

    Reg#(Bit#(1)) rg_rx <- mkReg(1);

    rule rconn;
        dut.rx._write(rg_rx);
    endrule

    function Bit#(1) tx_line() = dut.tx._read();

    Stmt s = seq
        delay(5);

        expect_axi_read(m_rd, 'h00, 'h0001000d, OKAY);
        expect_axi_read(m_rd, 'h04, 'h00000000, OKAY);
        expect_axi_read(m_rd, 'h08, 'h00000000, OKAY);
        expect_axi_read_masked(m_rd, 'h0c, 'h00000400, 'h00000f03, OKAY);

        axi_write(m_wr, 'h04, 'h00000003, 4'b1111, OKAY);
        axi_write(m_wr, 'h08, 'h0000000b, 4'b1111, OKAY);
        expect_axi_read(m_rd, 'h04, 'h00000003, OKAY);
        expect_axi_read(m_rd, 'h08, 'h0000000b, OKAY);

        axi_write(m_wr, 'h10, 'h000000a5, 4'b0011, SLVERR);
        delay(4);
        action
            if(dut.tx._read() != 1) begin
                $display("ERROR TestUartRegs: invalid TXDATA strobe started transmission");
                $finish(1);
            end
        endaction

        axi_write(m_wr, 'h10, 'h0000005a, 4'b0001, OKAY);
        expect_uart_Xn1(11, tx_line, 8'h5a);
        delay(11);
        action
            if(dut.tx._read() != 1) begin
                $display("ERROR TestUartRegs: second stop bit was low");
                $finish(1);
            end
        endaction
        expect_axi_read_masked(m_rd, 'h0c, 'h00000400, 'h00000c00, OKAY);

        drive_uart_frame(11, rg_rx, 8'h3c);
        delay(16);
        expect_axi_read_masked(m_rd, 'h0c, 'h00000c00, 'h00000c00, OKAY);
        expect_axi_read(m_rd, 'h14, 'h0000003c, OKAY);
        expect_axi_read(m_rd, 'h14, 'h00000000, SLVERR);
        expect_axi_read_masked(m_rd, 'h0c, 'h00000400, 'h00000c00, OKAY);

        drive_uart_frame_with_stop(11, rg_rx, 8'h66, 0);
        rg_rx <= 1;
        delay(20);
        expect_axi_read_masked(m_rd, 'h0c, 'h00000401, 'h00000403, OKAY);
        axi_write(m_wr, 'h0c, 'h00000001, 4'b0001, OKAY);
        delay(2);
        expect_axi_read_masked(m_rd, 'h0c, 'h00000400, 'h00000403, OKAY);

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
