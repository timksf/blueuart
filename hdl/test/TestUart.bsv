// SPDX-License-Identifier: MIT

package TestUart;

import StmtFSM :: *;

function Stmt drive_uart_data_bits_with_stop(Integer clocks_per_bit,Reg#(Bit#(1)) uart_line,Bit#(n) data,Bit#(1) stop_level,Integer bit_index);
    UInt#(16) delay_cycles = fromInteger(clocks_per_bit - 1);

    if(bit_index < valueof(n)) begin
        return seq
            uart_line <= data[bit_index];
            delay(delay_cycles);
            drive_uart_data_bits_with_stop(clocks_per_bit, uart_line, data, stop_level, bit_index + 1);
        endseq;
    end else begin
        return seq
            uart_line <= stop_level;
            delay(delay_cycles);
        endseq;
    end
endfunction

function Stmt drive_uart_frame(Integer clocks_per_bit, Reg#(Bit#(1)) uart_line, Bit#(n) data);
    return seq
        uart_line <= 0;
        delay(UInt#(16)'(fromInteger(clocks_per_bit - 1)));
        drive_uart_data_bits_with_stop(clocks_per_bit, uart_line, data, 1, 0);
    endseq;
endfunction

function Stmt drive_uart_frame_with_stop(Integer clocks_per_bit, Reg#(Bit#(1)) uart_line, Bit#(n) data, Bit#(1) stop_level);
    return seq
        uart_line <= 0;
        delay(UInt#(16)'(fromInteger(clocks_per_bit - 1)));
        drive_uart_data_bits_with_stop(clocks_per_bit, uart_line, data, stop_level, 0);
    endseq;
endfunction

function Stmt expect_uart_data_bits(Integer clocks_per_bit, function Bit#(1) uart_line(), Bit#(n) expected, Integer bit_index);
    if(bit_index < valueof(n)) begin
        return seq
            delay(UInt#(16)'(fromInteger(clocks_per_bit - 1)));
            action
                if(uart_line() != expected[bit_index])
                    $display(
                        "ERROR TestUartTx: data bit %0d expected %0d, received %0d", bit_index, expected[bit_index], uart_line()
                    );
            endaction
            expect_uart_data_bits(clocks_per_bit, uart_line, expected, bit_index + 1);
        endseq;
    end else begin
        return seq
            delay(UInt#(16)'(fromInteger(clocks_per_bit - 1)));
            action
                if(uart_line() != 1)
                    $display("ERROR TestUartTx: stop bit was low");
            endaction
        endseq;
    end
endfunction

function Stmt expect_uart_Xn1(Integer clocks_per_bit, function Bit#(1) uart_line(), Bit#(n) expected);
    return seq
        await(uart_line() == 0);
        delay(UInt#(16)'(fromInteger((clocks_per_bit / 2) - 1)));
        action
            if(uart_line() != 0)
                $display("ERROR TestUartTx: invalid start bit");
        endaction
        expect_uart_data_bits(clocks_per_bit, uart_line, expected, 0);
    endseq;
endfunction

endpackage
