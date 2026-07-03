# SPDX-License-Identifier: MIT

set bitstream_path [lindex $argv 0]
if {$bitstream_path eq ""} {
    error "usage: vivado -mode batch -source program_bitstream.tcl -tclargs <bitstream.bit>"
}

open_hw_manager
connect_hw_server
open_hw_target
set dev [lindex [get_hw_devices] 0]
current_hw_device $dev
set_property PROGRAM.FILE $bitstream_path $dev
program_hw_devices $dev
refresh_hw_device $dev
close_hw_manager
exit
