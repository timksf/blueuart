# SPDX-License-Identifier: MIT
# vivado -mode batch -source report_usage.tcl -tclargs <rtl-dir> <bsc-lib-dir> <report-dir>

if {$argc < 3} {
    error "usage: report_usage.tcl <rtl-dir> <bsc-lib-dir> <report-dir> ?tops...?"
}
set script_dir [file dirname [file normalize [info script]]]
set rtl_dir [file normalize [lindex $argv 0]]
set bsc_lib_dir [file normalize [lindex $argv 1]]
set report_dir [file normalize [lindex $argv 2]]
file mkdir $report_dir
set_param general.maxThreads 4
cd $report_dir
set summary [open [file join $report_dir usage.tsv] w]
puts $summary "top\tLUTs\tFFs\tWNS_ns"

# Match BSVTools: the Vivado-specific primitives override generic versions.
set primitives [dict create]
foreach dir {Verilog Verilog.Vivado} {
    foreach path [glob -directory [file join $bsc_lib_dir $dir] *.v] {
        if {[file tail $path] ne "main.v"} {
            dict set primitives [file tail $path] $path
        }
    }
}

set tops {
    mkUsageUartRxMin mkUsageUartRxMax
    mkUsageUartTxMin mkUsageUartTxMax
    mkUsageUartCoreMin mkUsageUartCoreMax
    mkUsageUartCsrMin mkUsageUartCsrMax
    mkUsageUartAxisBridgeMin mkUsageUartAxisBridgeMax
    mkUsageUartAxisBridgeCsrMin
    mkUsageUartAxiLiteMasterMin mkUsageUartAxiLiteMaster8MaxUart
    mkUsageUartAxiLiteMaster32MinUart mkUsageUartAxiLiteMasterMax
    mkUsageUartNarrow
}

if {$argc > 3} {
    set tops [lrange $argv 3 end]
}

foreach top $tops {
    puts "BLUEUART_USAGE_START $top"
    create_project -in_memory -part xc7a35tcpg236-1
    read_verilog [dict values $primitives]
    read_verilog [file join $rtl_dir ${top}.v]
    set project_name $top
    set project_dir $report_dir
    source [file join $script_dir synth_usage_analysis.tcl]
    set paths [get_timing_paths -setup -max_paths 1]
    if {[llength $paths] == 0} {
        error "No timed register path found for $top"
    }
    set wns [get_property SLACK [lindex $paths 0]]
    set file [open [file join $report_dir ${top}_wns.txt] w]
    puts $file $wns
    close $file
    set file [open [file join $report_dir ${top}_util_synth.rpt] r]
    set utilization [read $file]
    close $file
    if {![regexp {\| Slice LUTs\* *\| *([0-9]+)} $utilization unused luts] ||
        ![regexp {\|   Register as Flip Flop *\| *([0-9]+)} $utilization unused ffs]} {
        error "Could not extract utilization for $top"
    }
    puts $summary "$top\t$luts\t$ffs\t$wns"
    flush $summary
    puts "BLUEUART_USAGE_DONE $top LUTs=$luts FFs=$ffs WNS=$wns"
    close_project
}
close $summary
puts "BLUEUART_USAGE_ALL_DONE"
