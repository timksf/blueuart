# SPDX-License-Identifier: MIT

set_property -dict { PACKAGE_PIN L17 IOSTANDARD LVCMOS33 } [get_ports { clk_12 }]
create_clock -add -name clk_12 -period 83.333 -waveform {0 41.666} [get_ports { clk_12 }]

set_property -dict { PACKAGE_PIN A17 IOSTANDARD LVCMOS33 } [get_ports { led[0] }]
set_property -dict { PACKAGE_PIN C16 IOSTANDARD LVCMOS33 } [get_ports { led[1] }]

set_property -dict { PACKAGE_PIN J17 IOSTANDARD LVCMOS33 } [get_ports { uart_rxd }]
set_property -dict { PACKAGE_PIN J18 IOSTANDARD LVCMOS33 } [get_ports { uart_txd }]