# SPDX-License-Identifier: MIT

###
# DO NOT CHANGE
###
TOP_MODULE=mkUartCore
TESTBENCH_MODULE=mkTestbench
IGNORE_MODULES=mkTestbench mkTestsMainTest
MAIN_MODULE=BlueUART
TESTBENCH_FILE=test/Testbench.bsv
TEST_DIR=$(CURDIR)/test

# Initialize
-include .bsv_tools
ifndef BSV_TOOLS
BSV_TOOLS := $(CURDIR)/../dep/BSVTools
endif
VIVADO_ADD_PARAMS := ''
CONSTRAINT_FILES := ''
EXTRA_BSV_LIBS:=
EXTRA_LIBRARIES:=
RUN_FLAGS:=

PROJECT_NAME=BlueUART

ifeq ($(RUN_TEST),)
RUN_TEST=TestsMainTest
endif
TEST_TOP?=mk$(RUN_TEST)

# Default flags
EXTRA_FLAGS=-D "RUN_TEST=$(RUN_TEST)" -D "TESTNAME=$(TEST_TOP)"
EXTRA_FLAGS+=-show-schedule -D "BSV_TIMESCALE=1ns/1ps" -no-warn-action-shadowing 
# -steps-warn-interval 1000000

###
# User configuration
###

# Comment the following line if -O3 should be used during compilation
# Keep uncommented for short running simulations
CXX_NO_OPT := 1

# Any additional files added during compilation
# For instance for BDPI or Verilog/VHDL files for simulation
# CPP_FILES += $(current_dir)/src/mem_sim.cpp

# Custom defines added to compile steps
# EXTRA_FLAGS+=-D "BENCHMARK=1"

# Flags added to simulator execution
RUN_FLAGS+=-V dump.vcd

TYPED_VCD?=build/dump.typed.vcd
STRESS_TYPED_VCD?=build/wave_types.typed.vcd
BLUELENS?=$(CURDIR)/../dep/bluelens/annotate_bsv_vcd.tcl
REGRESSION_TESTS?=TestBaudGen TestUartRx TestUartTx TestUartRxModes TestUartRxOverflow TestUartLoopback TestUartCore TestUartAxisBridge TestUartAxisBridgeCsr TestUartAxiLiteMaster

# Add additional parameters for IP-XACT generation. Passed directly to Vivado.
# Any valid TCL during packaging is allowed
# Typically used to fix automatic inference for e.g. clock assignments
# VIVADO_ADD_PARAMS += 'ipx::associate_bus_interfaces -busif M_AXI -clock sconfig_axi_aclk [ipx::current_core]'

# Add custom constraint files, Syntax: Filename,Load Order
# CONSTRAINT_FILES += "$(CURDIR)/constraints/custom.xdc,LATE"

VERILOG_SIM:=
SYNTH_TARGET:=
PNR_OPTIONS:=
CONSTRAINT_FILES:=
YOSYS_CUSTOM_COMMANDS:=
RENDER_NETLIST:=
RENDER_CONVERT:=

# custom TCL flow
# PART ?= xcku3p-ffvb676-2-e
# SCRIPT ?= $(CURDIR)/synth.tcl

# Do not change: Load libraries such as BlueAXI or BlueLib
ifneq ("$(wildcard $(CURDIR)/libraries/*/*.mk)", "")
include $(CURDIR)/libraries/*/*.mk
endif

# Do not change: Include base makefile
include $(BSV_TOOLS)/scripts/rules.mk

.PHONY: wave_typed sim_typed_vcd
wave_typed: sim_typed_vcd

.PHONY: regression
regression:
	@REGRESSION_TESTS="$(REGRESSION_TESTS)" bash $(CURDIR)/script/regression.sh

sim_typed_vcd:
	$(MAKE) RUN_TEST=$(RUN_TEST) TEST_TOP=$(TEST_TOP) sim
	cd $(CURDIR)/.. && bluetcl $(BLUELENS) \
		--top $(TEST_TOP) \
		--build hdl/build \
		--vcd hdl/build/dump.vcd \
		--out hdl/$(TYPED_VCD) \
		--hide-source \
		--include '/*'

.PHONY: wave_types
wave_types:
	$(MAKE) RUN_TEST=TestWaveTypes sim
	cd $(CURDIR)/.. && bluetcl $(BLUELENS) \
		--top mkTestWaveTypes \
		--build hdl/build \
		--vcd hdl/build/dump.vcd \
		--out hdl/$(STRESS_TYPED_VCD) \
		--hide-source \
		--include '/rg_*'
