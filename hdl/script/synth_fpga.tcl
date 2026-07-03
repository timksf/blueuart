# SPDX-License-Identifier: MIT

read_xdc [file join [file dirname $script_path] constr.xdc]

set synth_top $project_name
set synth_file [file join $src_path "${synth_top}.v"]

if {![file exists $synth_file]} {
    error "Expected top Verilog '$synth_file'. For this script, PROJECT_NAME must match the synthesized Verilog top module."
}

puts "Using project_name as synthesis top: $synth_top"
synth_design -top $synth_top
puts "Finished synth_design"

opt_design
puts "Finished opt_design"

report_timing_summary -file $project_dir/${project_name}_tim1.rpt
report_utilization -file $project_dir/${project_name}_util1.rpt
report_drc -file $project_dir/${project_name}_drc1.rpt

write_checkpoint -force $project_dir/${project_name}_drc.dcp

place_design
puts "Finished place_design"

route_design
puts "Finished route_design"

report_timing_summary -file $project_dir/${project_name}_tim_route.rpt
report_utilization -file $project_dir/${project_name}_util_route.rpt

write_checkpoint -force $project_dir/${project_name}_pnr.dcp

phys_opt_design
puts "Finished phys_opt_design"

report_timing_summary -file $project_dir/${project_name}_tim_physopt_route.rpt
report_utilization -file $project_dir/${project_name}_util_physopt_route.rpt
report_drc -file $project_dir/${project_name}_drc_physopt_route.rpt

write_checkpoint -force $project_dir/${project_name}_physopt.dcp

write_bitstream -force $project_dir/${project_name}.bit
puts "Finished write_bitstream"
