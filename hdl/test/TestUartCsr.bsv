// SPDX-License-Identifier: MIT

package TestUartCsr;

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

module [Module] mkUartCsrRegisterTest(TestHelper::TestHandler);

    UartCsr_ifc dut <- mkUartCsr(2, 2);

    AXI4_Lite_Master_Wr#(32, 32) m_wr <- mkAXI4_Lite_Master_Wr(2);
    AXI4_Lite_Master_Rd#(32, 32) m_rd <- mkAXI4_Lite_Master_Rd(2);

    mkConnection(m_wr.fab, dut.s_wr);
    mkConnection(m_rd.fab, dut.s_rd);

    Reg#(Bit#(1)) rg_rx <- mkReg(1);

    rule rconn;
        dut.rx(rg_rx);
    endrule

    function Bit#(1) tx_line() = dut.tx();

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
            if(dut.tx() != 1) begin
                $display("ERROR TestUartRegs: invalid TXDATA strobe started transmission");
                $finish(1);
            end
        endaction

        axi_write(m_wr, 'h10, 'h0000005a, 4'b0001, OKAY);
        expect_uart_Xn1(11, tx_line, 8'h5a);
        delay(11);
        action
            if(dut.tx() != 1) begin
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

    endseq;

    FSM testFSM <- mkFSM(s);

    method Action go();
        testFSM.start();
    endmethod

    method Bool done();
        return testFSM.done();
    endmethod

endmodule

module [Module] mkUartCsrFifoTest(TestHandler);
    UartCsr_ifc dut <- mkUartCsr(2, 2);
    AXI4_Lite_Master_Wr#(32, 32) m_wr <- mkAXI4_Lite_Master_Wr(2);
    AXI4_Lite_Master_Rd#(32, 32) m_rd <- mkAXI4_Lite_Master_Rd(2);
    mkConnection(m_wr.fab, dut.s_wr);
    mkConnection(m_rd.fab, dut.s_rd);

    Reg#(Bit#(1)) rg_rx <- mkReg(1);
    Reg#(Bit#(8)) rg_index <- mkReg(0);
    rule r_connect;
        dut.rx(rg_rx);
    endrule
    function Bit#(1) tx_line() = dut.tx;

    Stmt s = seq
        delay(5);
        axi_write(m_wr, 'h08, 11, 4'b0011, OKAY);
        axi_write(m_wr, 'h04, 1, 4'b0001, OKAY);
        for(rg_index <= 0; rg_index < 4; rg_index <= rg_index + 1)
            drive_uart_frame(11, rg_rx, 8'h12 + rg_index);
        delay(20);
        expect_axi_read_masked(m_rd, 'h0c, 'h802, 'h803, OKAY);
        expect_axi_read(m_rd, 'h14, 'h12, OKAY);
        expect_axi_read(m_rd, 'h14, 'h13, OKAY);
        // The newest word is retained in the zero-depth RX assembly register.
        expect_axi_read(m_rd, 'h14, 'h15, OKAY);
        expect_axi_read(m_rd, 'h14, 0, SLVERR);
        axi_write(m_wr, 'h0c, 2, 4'b0001, OKAY);
        drive_uart_frame(11, rg_rx, 8'h78);
        delay(10);
        expect_axi_read(m_rd, 'h14, 'h78, OKAY);
        expect_axi_read_masked(m_rd, 'h0c, 0, 3, OKAY);

        axi_write(m_wr, 'h04, 0, 4'b0001, OKAY);
        axi_write(m_wr, 'h10, 'h81, 4'b0001, OKAY);
        axi_write(m_wr, 'h10, 'h82, 4'b0001, OKAY);
        axi_write(m_wr, 'h10, 'ha3, 4'b0001, SLVERR);
        expect_axi_read_masked(m_rd, 'h0c, 'h100, 'h500, OKAY);
        action
            if(dut.tx != 1) begin
                $display("ERROR TestUartCsr: disabled UART started queued data");
                $finish(1);
            end
        endaction
        axi_write(m_wr, 'h04, 1, 4'b0001, OKAY);
        for(rg_index <= 0; rg_index < 2; rg_index <= rg_index + 1)
            expect_uart_Xn1(11, tx_line, 8'h81 + rg_index);
        delay(20);
        expect_axi_read_masked(m_rd, 'h0c, 'h400, 'h500, OKAY);
    endseq;
    FSM i_test <- mkFSM(s);
    method go = i_test.start;
    method done = i_test.done;
endmodule

(* synthesize *)
module mkTestUartCsr(TestHandler);
    TestHandler i_regs <- mkUartCsrRegisterTest;
    TestHandler i_fifos <- mkUartCsrFifoTest;
    Reg#(UInt#(16)) rg_cycles <- mkReg(0);
    rule r_watchdog;
        rg_cycles <= rg_cycles + 1;
        if(rg_cycles == 20000) begin
            $display("ERROR TestUartCsr: timeout");
            $finish(1);
        end
    endrule
    Stmt s = seq
        action
            i_regs.go;
            i_fifos.go;
        endaction
        await(i_regs.done && i_fifos.done);
        $display("All tests finished successfully");
    endseq;
    FSM i_test <- mkFSM(s);
    method go = i_test.start;
    method done = i_test.done;
endmodule

endpackage
