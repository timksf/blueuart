// SPDX-License-Identifier: MIT

package UartAxisBridge;

import AXI4_Lite_Slave :: *;
import AXI4_Stream :: *;
import BlueUART :: *;
import UartRx :: *;
import UartTx :: *;
import GetPut :: *;

interface UartAxisBridge#(numeric type datawidth, numeric type userwidth);
    (* always_enabled *) (* prefix="uart" *)
    method Action rx(Bit#(1) value);
    (* always_ready *) (* result="uart_tx" *)
    method Bit#(1) tx();

    interface AXI4_Stream_Wr_Fab#(datawidth, userwidth) m_axis;
    interface AXI4_Stream_Rd_Fab#(datawidth, userwidth) s_axis;

    (* always_ready *) method Bool rx_busy;
    (* always_ready *) method Bool tx_busy;
endinterface

interface UartAxisBridgeCsr#(numeric type datawidth, numeric type userwidth);
    (* always_enabled *) (* prefix="uart" *)
    method Action rx(Bit#(1) value);
    (* always_ready *) (* result="uart_tx" *)
    method Bit#(1) tx();

    (* prefix="M_AXIS" *) interface AXI4_Stream_Wr_Fab#(datawidth, userwidth) m_axis;
    (* prefix="S_AXIS" *) interface AXI4_Stream_Rd_Fab#(datawidth, userwidth) s_axis;

    (* prefix="S_AXI_cfg" *) interface AXI4_Lite_Slave_Rd_Fab#(32, 32) s_rd;
    (* prefix="S_AXI_cfg" *) interface AXI4_Lite_Slave_Wr_Fab#(32, 32) s_wr;

    (* always_ready *) method Bool rx_busy;
    (* always_ready *) method Bool tx_busy;
endinterface

function AXI4_Stream_Pkg#(datawidth, userwidth) uart_word_to_axis(Bit#(datawidth) data)
    provisos(Div#(datawidth, 8, keepwidth));
    return AXI4_Stream_Pkg {
        data: data,
        user: 0,
        keep: '1,
        dest: 0,
        id:   0,
        last: True
    };
endfunction

module [Module] mkUartAxisBridgeBuffered#(Bit#(2) stop_bits, Bit#(16) prescaler, Integer m_axis_buffer, Integer s_axis_buffer, Integer rx_buffer, Integer tx_buffer)(UartAxisBridge#(datawidth, userwidth))
    provisos(
        Add#(a__, 1, datawidth),
        Div#(datawidth, 8, keepwidth),
        Log#(datawidth, datawidth_log),
        Add#(datawidth_log, 1, datawidth_log1)
    );

    UartRx#(datawidth) uart_rx <- mkUartRxBuffered(stop_bits, prescaler, rx_buffer);
    UartTx#(datawidth) uart_tx <- mkUartTxBuffered(stop_bits, prescaler, tx_buffer);

    AXI4_Stream_Wr#(datawidth, userwidth) axis_out <- mkAXI4_Stream_Wr(m_axis_buffer);
    AXI4_Stream_Rd#(datawidth, userwidth) axis_in <- mkAXI4_Stream_Rd(s_axis_buffer);

    rule rrx_to_axis;
        let data <- uart_rx.receive.get();
        axis_out.pkg.put(uart_word_to_axis(data));
    endrule

    rule raxis_to_tx;
        let data <- axis_in.pkg.get();
        uart_tx.transmit.put(data.data);
    endrule

    method rx = uart_rx.rx;
    method tx = uart_tx.tx;
    method rx_busy = uart_rx.busy;
    method tx_busy = uart_tx.busy;

    interface m_axis = axis_out.fab;
    interface s_axis = axis_in.fab;
endmodule

module [Module] mkUartAxisBridge#(Bit#(2) stop_bits, Bit#(16) prescaler, Integer m_axis_buffer, Integer s_axis_buffer)(UartAxisBridge#(datawidth, userwidth))
    provisos(
        Add#(a__, 1, datawidth),
        Div#(datawidth, 8, keepwidth),
        Log#(datawidth, datawidth_log),
        Add#(datawidth_log, 1, datawidth_log1)
    );

    let bridge <- mkUartAxisBridgeBuffered(stop_bits, prescaler, m_axis_buffer, s_axis_buffer, 2, 2);
    return bridge;
endmodule

module [Module] mkUartAxisBridgeCsrBuffered#(Integer m_axis_buffer, Integer s_axis_buffer, Integer rx_buffer, Integer tx_buffer)(UartAxisBridgeCsr#(datawidth, userwidth))
    provisos(
        Add#(datawidth, 0, 8),
        Div#(datawidth, 8, keepwidth),
        Log#(datawidth, datawidth_log),
        Add#(datawidth_log, 1, datawidth_log1)
    );

    UartCore uart <- mkUartCore(rx_buffer, tx_buffer, False);
    
    AXI4_Stream_Wr#(datawidth, userwidth) axis_out <- mkAXI4_Stream_Wr(m_axis_buffer);
    AXI4_Stream_Rd#(datawidth, userwidth) axis_in <- mkAXI4_Stream_Rd(s_axis_buffer);

    rule rrx_to_axis;
        let data <- uart.receive.get();
        axis_out.pkg.put(uart_word_to_axis(data));
    endrule

    rule raxis_to_tx;
        let data <- axis_in.pkg.get();
        uart.transmit.put(data.data);
    endrule

    method Action rx(Bit#(1) value);
        uart.rx._write(value);
    endmethod
    method tx = uart.tx._read;
    method rx_busy = uart.rx_busy;
    method tx_busy = uart.tx_busy;

    interface m_axis = axis_out.fab;
    interface s_axis = axis_in.fab;
    interface s_rd = uart.s_rd;
    interface s_wr = uart.s_wr;
endmodule

module [Module] mkUartAxisBridgeCsr#(Integer m_axis_buffer, Integer s_axis_buffer)(UartAxisBridgeCsr#(datawidth, userwidth))
    provisos(
        Add#(datawidth, 0, 8),
        Div#(datawidth, 8, keepwidth),
        Log#(datawidth, datawidth_log),
        Add#(datawidth_log, 1, datawidth_log1)
    );

    let bridge <- mkUartAxisBridgeCsrBuffered(m_axis_buffer, s_axis_buffer, 2, 2);
    return bridge;
endmodule

endpackage
