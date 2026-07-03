// SPDX-License-Identifier: MIT

package UartUsageAnalysis;

import UartRx :: *;
import UartTx :: *;
import UartCore :: *;
import UartAxisBridge :: *;
import UartAxiLiteMaster :: *;

typedef Bit#(2) StopBits;
typedef Bit#(16) Prescaler;

StopBits stop_1 = 1;
Prescaler ref_100mhz_115200 = 868;

(* synthesize *)
module mkUsageUartRxMin(UartRx#(8));
    let uart <- mkUartRxBuffered(stop_1, ref_100mhz_115200, 1);
    return uart;
endmodule

(* synthesize *)
module mkUsageUartRxMax(UartRx#(8));
    let uart <- mkUartRxBuffered(stop_1, ref_100mhz_115200, 16);
    return uart;
endmodule

(* synthesize *)
module mkUsageUartTxMin(UartTx#(8));
    let uart <- mkUartTxBuffered(stop_1, ref_100mhz_115200, 1);
    return uart;
endmodule

(* synthesize *)
module mkUsageUartTxMax(UartTx#(8));
    let uart <- mkUartTxBuffered(stop_1, ref_100mhz_115200, 16);
    return uart;
endmodule

(* synthesize *)
module mkUsageUartCoreMin(UartCore);
    let uart <- mkUartCore(1, 1, True);
    return uart;
endmodule

(* synthesize *)
module mkUsageUartCoreMax(UartCore);
    let uart <- mkUartCore(16, 16, True);
    return uart;
endmodule

(* synthesize *)
module mkUsageUartCoreCtrlOnlyMax(UartCore);
    let uart <- mkUartCore(16, 16, False);
    return uart;
endmodule

(* synthesize *)
module mkUsageUartAxisBridgeMin(UartAxisBridge#(8, 1));
    let bridge <- mkUartAxisBridgeBuffered(stop_1, ref_100mhz_115200, 1, 1, 1, 1);
    return bridge;
endmodule

(* synthesize *)
module mkUsageUartAxisBridgeMax(UartAxisBridge#(8, 1));
    let bridge <- mkUartAxisBridgeBuffered(stop_1, ref_100mhz_115200, 1, 1, 16, 16);
    return bridge;
endmodule

(* synthesize *)
module mkUsageUartAxiLiteMasterMin(UartAxiLiteMaster#(8, 8));
    let master <- mkUartAxiLiteMasterBuffered(stop_1, ref_100mhz_115200, 1, 1, 1, 1);
    return master;
endmodule

(* synthesize *)
module mkUsageUartAxiLiteMaster32MinUart(UartAxiLiteMaster#(32, 32));
    let master <- mkUartAxiLiteMasterBuffered(stop_1, ref_100mhz_115200, 1, 1, 1, 1);
    return master;
endmodule

(* synthesize *)
module mkUsageUartAxiLiteMaster8MaxUart(UartAxiLiteMaster#(8, 8));
    let master <- mkUartAxiLiteMasterBuffered(stop_1, ref_100mhz_115200, 1, 1, 16, 16);
    return master;
endmodule

(* synthesize *)
module mkUsageUartAxiLiteMasterMax(UartAxiLiteMaster#(32, 32));
    let master <- mkUartAxiLiteMasterBuffered(stop_1, ref_100mhz_115200, 1, 1, 16, 16);
    return master;
endmodule

endpackage
