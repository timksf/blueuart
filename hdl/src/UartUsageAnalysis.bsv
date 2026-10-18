// SPDX-License-Identifier: MIT

package UartUsageAnalysis;

import UartRx :: *;
import UartTx :: *;
import UartCore :: *;
import UartCsr :: *;
import UartAxisBridge :: *;
import UartAxiLiteMaster :: *;

typedef Bit#(2) StopBits;
typedef Bit#(16) Prescaler;

StopBits stop_1 = 1;
Prescaler ref_100mhz_115200 = 868;

(* synthesize *)
module mkUsageUartRxMin(UartRx#(8));
    let uart <- mkUartRx(stop_1, ref_100mhz_115200, 0);
    return uart;
endmodule

(* synthesize *)
module mkUsageUartRxMax(UartRx#(8));
    let uart <- mkUartRx(stop_1, ref_100mhz_115200, 16);
    return uart;
endmodule

(* synthesize *)
module mkUsageUartTxMin(UartTx#(8));
    let uart <- mkUartTx(stop_1, ref_100mhz_115200, 0);
    return uart;
endmodule

(* synthesize *)
module mkUsageUartTxMax(UartTx#(8));
    let uart <- mkUartTx(stop_1, ref_100mhz_115200, 16);
    return uart;
endmodule

(* synthesize *)
module mkUsageUartCoreMin(UartCore_ifc#(8));
    let uart <- mkUartCore(True, stop_1, ref_100mhz_115200, 0, 0);
    return uart;
endmodule

(* synthesize *)
module mkUsageUartCoreMax(UartCore_ifc#(8));
    let uart <- mkUartCore(True, stop_1, ref_100mhz_115200, 16, 16);
    return uart;
endmodule

(* synthesize *)
module mkUsageUartCsrMin(UartCsr_ifc);
    let uart <- mkUartCsr(1, 1);
    return uart;
endmodule

(* synthesize *)
module mkUsageUartCsrMax(UartCsr_ifc);
    let uart <- mkUartCsr(16, 16);
    return uart;
endmodule

(* synthesize *)
module mkUsageUartAxisBridgeMin(UartAxisBridge#(8, 1));
    let bridge <- mkUartAxisBridge(stop_1, ref_100mhz_115200, 1, 1, 1, 1);
    return bridge;
endmodule

(* synthesize *)
module mkUsageUartAxisBridgeMax(UartAxisBridge#(8, 1));
    let bridge <- mkUartAxisBridge(stop_1, ref_100mhz_115200, 1, 1, 16, 16);
    return bridge;
endmodule

(* synthesize *)
module mkUsageUartAxiLiteMasterMin(UartAxiLiteMaster#(8, 8));
    let master <- mkUartAxiLiteMaster(stop_1, ref_100mhz_115200, 1, 1, 1, 1);
    return master;
endmodule

(* synthesize *)
module mkUsageUartAxiLiteMaster32MinUart(UartAxiLiteMaster#(32, 32));
    let master <- mkUartAxiLiteMaster(stop_1, ref_100mhz_115200, 1, 1, 1, 1);
    return master;
endmodule

(* synthesize *)
module mkUsageUartAxiLiteMaster8MaxUart(UartAxiLiteMaster#(8, 8));
    let master <- mkUartAxiLiteMaster(stop_1, ref_100mhz_115200, 1, 1, 16, 16);
    return master;
endmodule

(* synthesize *)
module mkUsageUartAxiLiteMasterMax(UartAxiLiteMaster#(32, 32));
    let master <- mkUartAxiLiteMaster(stop_1, ref_100mhz_115200, 1, 1, 16, 16);
    return master;
endmodule

(* synthesize *)
module mkUsageUartAxisBridgeCsrMin(UartAxisBridgeCsr#(8, 1));
    let bridge <- mkUartAxisBridgeCsr(1, 1, 0, 0);
    return bridge;
endmodule

(* synthesize *)
module mkUsageUartNarrow(UartCore_ifc#(1));
    let uart <- mkUartCore(True, stop_1, ref_100mhz_115200, 0, 0);
    return uart;
endmodule

endpackage
