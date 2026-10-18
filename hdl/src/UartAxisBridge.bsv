// SPDX-License-Identifier: MIT

package UartAxisBridge;

import AXI4_Lite_Slave :: *;
import AXI4_Stream :: *;
import BlueCSRCore :: *;
import BlueCSRAXI4LiteAdapter :: *;
import UartCore :: *;
import UartRegs :: *;
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

module [Module] mkUartAxisBridge#(Bit#(2) stop_bits, Bit#(16) prescaler, Integer m_axis_buffer, Integer s_axis_buffer, Integer rx_buffer, Integer tx_buffer)(UartAxisBridge#(datawidth, userwidth))
    provisos(
        Add#(a__, 1, datawidth),
        Div#(datawidth, 8, keepwidth),
        Log#(datawidth, datawidth_log),
        Add#(datawidth_log, 1, datawidth_log1)
    );

    UartCore_ifc#(datawidth) i_uart <- mkUartCore(True, stop_bits, prescaler, rx_buffer, tx_buffer);

    AXI4_Stream_Wr#(datawidth, userwidth) i_axis_out <- mkAXI4_Stream_Wr(m_axis_buffer);
    AXI4_Stream_Rd#(datawidth, userwidth) i_axis_in <- mkAXI4_Stream_Rd(s_axis_buffer);

    rule r_rx_to_axis;
        let data <- i_uart.receive.get();
        i_axis_out.pkg.put(uart_word_to_axis(data));
    endrule

    rule r_axis_to_tx;
        let data <- i_axis_in.pkg.get();
        i_uart.transmit.put(data.data);
    endrule

    method rx = i_uart.rx;
    method tx = i_uart.tx;
    method rx_busy = i_uart.rx_busy;
    method tx_busy = i_uart.tx_busy;

    interface m_axis = i_axis_out.fab;
    interface s_axis = i_axis_in.fab;
endmodule

module [Module] mkUartAxisBridgeCsr#(Integer m_axis_buffer, Integer s_axis_buffer, Integer rx_buffer, Integer tx_buffer)(UartAxisBridgeCsr#(datawidth, userwidth))
    provisos(
        Add#(datawidth, 0, 8),
        Div#(datawidth, 8, keepwidth),
        Log#(datawidth, datawidth_log),
        Add#(datawidth_log, 1, datawidth_log1)
    );

    BlueCSRAccess_ifc#(32, 32, 0, UartControlRegs_ifc) i_csrs <-
        create_blue_csr(uart_control_csrs, False);
    BlueCSR_AXI4Lite_ifc#(32, 32, 0) i_axi_csrs <- mkBlueCSRAXI4LiteAdapter(i_csrs.external, 1, 1);
    Bit#(2) stop_bits = i_csrs.internal.ctrl_s2 ? 2 : 1;
    UartCore_ifc#(datawidth) i_uart <- mkUartCore(
        i_csrs.internal.ctrl_en, stop_bits, i_csrs.internal.prescaler, rx_buffer, tx_buffer);

    AXI4_Stream_Wr#(datawidth, userwidth) i_axis_out <- mkAXI4_Stream_Wr(m_axis_buffer);
    AXI4_Stream_Rd#(datawidth, userwidth) i_axis_in <- mkAXI4_Stream_Rd(s_axis_buffer);

    rule r_errors;
        i_csrs.internal.frame_error(i_uart.frame_error);
        i_csrs.internal.ovflw_error(i_uart.ovflw_error);
    endrule

    rule r_status;
        i_csrs.internal.rx_busy(i_uart.rx_busy);
        i_csrs.internal.tx_busy(i_uart.tx_busy);
        i_csrs.internal.rx_valid(i_axis_out.fab.tvalid);
        i_csrs.internal.tx_ready(i_axis_in.fab.tready);
    endrule

    rule r_rx_to_axis;
        let data <- i_uart.receive.get();
        i_axis_out.pkg.put(uart_word_to_axis(data));
    endrule

    rule r_axis_to_tx;
        let data <- i_axis_in.pkg.get();
        i_uart.transmit.put(data.data);
    endrule

    method rx = i_uart.rx;
    method tx = i_uart.tx;
    method rx_busy = i_uart.rx_busy;
    method tx_busy = i_uart.tx_busy;

    interface m_axis = i_axis_out.fab;
    interface s_axis = i_axis_in.fab;
    interface s_rd = i_axi_csrs.s_rd;
    interface s_wr = i_axi_csrs.s_wr;
endmodule

endpackage
