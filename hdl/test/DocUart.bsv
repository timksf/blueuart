// SPDX-License-Identifier: MIT

package DocUart;

import BlueCSRCore :: *;
import BlueCSRExport :: *;
import UartRegs :: *;

module [BlueCSRCtx_t#(32, 32)] uart_doc_csrs(UartRegs_ifc);
    // Queue depths do not change the register map.
    UartRegs_ifc i_regs <- uart_csrs(1, 1);

    rule r_idle_status;
        i_regs.control.frame_error(False);
        i_regs.control.ovflw_error(False);
        i_regs.control.tx_busy(False);
        i_regs.control.rx_busy(False);
        i_regs.control.tx_ready(True);
        i_regs.control.rx_valid(False);
    endrule

    return i_regs;
endmodule

module [Module] mkUartCSRMarkdown(Empty);
    RegMapDoc_t#(32) doc <- doc_blue_csr_markdown(uart_doc_csrs);

    rule r_write_markdown;
        File fh <- $fopen("register-map.md", "w");
        if(fh == InvalidFile) begin
            $display("Could not open register-map.md");
            $finish(1);
        end else begin
            $fwrite(fh, "%s\n", doc.reg_defs);
            $fwrite(fh, "TXDATA and RXDATA are optional FIFO registers: mkUartCsr includes them;\n");
            $fwrite(fh, "the control-only mkUartAxisBridgeCsr uses registers 0x00-0x0c only.\n");
            $fflush(fh);
            $fclose(fh);
            $display("Generated register-map.md");
            $finish(0);
        end
    endrule
endmodule

endpackage
