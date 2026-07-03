# SPDX-License-Identifier: MIT

set usage_top $project_name

synth_design -top $usage_top -mode out_of_context
puts "Finished synth_design for $usage_top"

if {[llength [get_ports -quiet CLK]]} {
    create_clock -name CLK -period 10.000 [get_ports CLK]
}

report_timing_summary -file $project_dir/${project_name}_tim_synth.rpt
report_utilization -file $project_dir/${project_name}_util_synth.rpt
