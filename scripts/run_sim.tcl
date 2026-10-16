# Locate the repository relative to this script.
set repo_dir [file normalize \
    [file join [file dirname [info script]] ..]]

# Use a new build directory for each run.
set build_dir [file join $repo_dir build \
    [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]]

create_project memsight $build_dir \
    -part xc7a35tcpg236-1

add_files [file join $repo_dir rtl memory_bank.sv]
add_files [file join $repo_dir rtl controller.sv]

add_files -fileset sim_1 \
    [file join $repo_dir tb tb_controller.sv]

set_property top controller [get_filesets sources_1]
set_property top tb_controller [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# Launch paused at time zero, then run the complete testbench.
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
launch_simulation
run all