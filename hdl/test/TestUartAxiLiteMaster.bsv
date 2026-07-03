// SPDX-License-Identifier: MIT

package TestUartAxiLiteMaster;

import AXI4_Lite_Slave :: *;
import AXI4_Lite_Types :: *;
import UartAxiLiteMaster :: *;
import Connectable :: *;
import GetPut :: *;
import StmtFSM :: *;

import TestHelper :: *;

function Stmt drive_uart_bits(Integer clocks_per_bit, Reg#(Bit#(1)) uart_line, Bit#(8) data, Integer bit_index);
    UInt#(16) delay_cycles = fromInteger(clocks_per_bit - 1);
    if(bit_index < 8) begin
        return seq
            uart_line <= data[bit_index];
            delay(delay_cycles);
            drive_uart_bits(clocks_per_bit, uart_line, data, bit_index + 1);
        endseq;
    end else begin
        return seq
            uart_line <= 1;
            delay(delay_cycles);
        endseq;
    end
endfunction

function Stmt drive_uart_byte(Integer clocks_per_bit, Reg#(Bit#(1)) uart_line, Bit#(8) data);
    UInt#(16) delay_cycles = fromInteger(clocks_per_bit - 1);
    return seq
        uart_line <= 0;
        delay(delay_cycles);
        drive_uart_bits(clocks_per_bit, uart_line, data, 0);
    endseq;
endfunction

function Stmt expect_uart_byte(Integer clocks_per_bit, function Bit#(1) uart_line(), Reg#(UInt#(4)) bit_index, Bit#(8) expected);
    UInt#(16) half_delay = fromInteger((clocks_per_bit / 2) - 1);
    UInt#(16) bit_delay = fromInteger(clocks_per_bit - 2);
    return seq
        await(uart_line() == 1);
        await(uart_line() == 0);
        delay(half_delay);
        action
            if(uart_line() != 0) begin
                $display("ERROR TestUartAxiLiteMaster: invalid UART response start bit");
                $finish(1);
            end
        endaction
        for(bit_index <= 0; bit_index < 8; bit_index <= bit_index + 1) seq
            delay(bit_delay);
            action
                if(uart_line() != expected[bit_index]) begin
                    $display(
                        "ERROR TestUartAxiLiteMaster: response bit %0d expected %0d, got %0d",
                        bit_index,
                        expected[bit_index],
                        uart_line()
                    );
                    $finish(1);
                end
            endaction
        endseq
        delay(bit_delay);
        action
            if(uart_line() != 1) begin
                $display("ERROR TestUartAxiLiteMaster: UART response stop bit was low");
                $finish(1);
            end
        endaction
    endseq;
endfunction

(* synthesize *)
module [Module] mkTestUartAxiLiteMaster(TestHandler);

    UartAxiLiteMaster#(8, 8) dut <- mkUartAxiLiteMaster(1, 11, 2, 2);
    AXI4_Lite_Slave_Rd#(8, 8) slave_rd <- mkAXI4_Lite_Slave_Rd(2);
    AXI4_Lite_Slave_Wr#(8, 8) slave_wr <- mkAXI4_Lite_Slave_Wr(2);

    mkConnection(dut.m_rd, slave_rd.fab);
    mkConnection(dut.m_wr, slave_wr.fab);

    Reg#(Bit#(1)) rg_rx <- mkReg(1);
    Reg#(Bool) rg_write_seen <- mkReg(False);
    Reg#(Bool) rg_error_write_seen <- mkReg(False);
    Reg#(UInt#(4)) rg_expect_bit_index <- mkReg(0);

    rule rconn;
        dut.rx(rg_rx);
    endrule

    rule rread_resp;
        let req <- slave_rd.request.get();
        if(req.addr == 8'h78) begin
            slave_rd.response.put(AXI4_Lite_Read_Rs_Pkg { data: 8'hbe, resp: OKAY });
        end else begin
            slave_rd.response.put(AXI4_Lite_Read_Rs_Pkg { data: 8'h00, resp: SLVERR });
        end
    endrule

    rule rwrite_resp;
        let req <- slave_wr.request.get();
        if(req.addr == 8'h21 && req.data == 8'hef && req.strb == '1) begin
            rg_write_seen <= True;
            slave_wr.response.put(AXI4_Lite_Write_Rs_Pkg { resp: OKAY });
        end else if(req.addr == 8'hd0) begin
            rg_error_write_seen <= True;
            slave_wr.response.put(AXI4_Lite_Write_Rs_Pkg { resp: SLVERR });
        end else begin
            $display("ERROR TestUartAxiLiteMaster: unexpected write addr=%02x data=%02x strb=%0h", req.addr, req.data, req.strb);
            $finish(1);
        end
    endrule

    function Bit#(1) tx_line() = dut.tx();

    Stmt s = seq
        delay(5);

        drive_uart_byte(11, rg_rx, 8'h01);
        drive_uart_byte(11, rg_rx, 8'h21);
        par
            drive_uart_byte(11, rg_rx, 8'hef);
            expect_uart_byte(11, tx_line, rg_expect_bit_index, 8'h00);
        endpar
        action
            if(!rg_write_seen) begin
                $display("ERROR TestUartAxiLiteMaster: write was not observed");
                $finish(1);
            end
        endaction

        drive_uart_byte(11, rg_rx, 8'h00);
        par
            drive_uart_byte(11, rg_rx, 8'h78);
            seq
                expect_uart_byte(11, tx_line, rg_expect_bit_index, 8'h00);
                expect_uart_byte(11, tx_line, rg_expect_bit_index, 8'hbe);
            endseq
        endpar

        drive_uart_byte(11, rg_rx, 8'h01);
        drive_uart_byte(11, rg_rx, 8'hd0);
        par
            drive_uart_byte(11, rg_rx, 8'h01);
            expect_uart_byte(11, tx_line, rg_expect_bit_index, 8'h01);
        endpar
        action
            if(!rg_error_write_seen) begin
                $display("ERROR TestUartAxiLiteMaster: error write was not observed");
                $finish(1);
            end
        endaction

        par
            drive_uart_byte(11, rg_rx, 8'hff);
            expect_uart_byte(11, tx_line, rg_expect_bit_index, 8'h02);
        endpar

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
