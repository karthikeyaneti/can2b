SIM ?= iverilog
VVP ?= vvp
GTKWAVE ?= gtkwave

TOP ?= tb_apb_interface
TB ?= sim/apb_interface/tb_apb_interface.v
RTL_SRCS ?= $(shell find src -type f -name '*.v' | sort)
EXTRA_SRCS ?=

BUILD_DIR ?= build/$(TOP)
OUT ?= $(BUILD_DIR)/$(TOP).vvp
VCD ?= $(BUILD_DIR)/$(TOP).vcd

IVERILOG_FLAGS ?= -g2012 -Wall -Wimplicit -Wportbind -Wselect-range -D VCD_FILE=\"$(VCD)\"

SRCS := $(RTL_SRCS) $(TB) $(EXTRA_SRCS)

.PHONY: all compile run wave clean help show-vars

all: run

compile: $(OUT)

run: $(OUT)
	$(VVP) $(OUT)

wave: $(OUT)
	$(VVP) $(OUT)
	$(GTKWAVE) $(VCD)

$(BUILD_DIR):
	mkdir -p $@

$(OUT): $(SRCS) | $(BUILD_DIR)
	$(SIM) $(IVERILOG_FLAGS) -o $@ $(SRCS)

clean:
	rm -rf build sim/waveforms

show-vars:
	@echo "SIM=$(SIM)"
	@echo "VVP=$(VVP)"
	@echo "TOP=$(TOP)"
	@echo "TB=$(TB)"
	@echo "RTL_SRCS=$(RTL_SRCS)"
	@echo "EXTRA_SRCS=$(EXTRA_SRCS)"
	@echo "OUT=$(OUT)"

help:
	@echo "Targets:"
	@echo "  make             Build and run the selected testbench"
	@echo "  make compile     Build only"
	@echo "  make run         Build and run"
	@echo "  make wave        Build, run, and open the VCD in GTKWave"
	@echo "  make clean       Remove build artifacts"
	@echo ""
	@echo "Common overrides:"
	@echo "  TOP=tb_name"
	@echo "  TB=sim/path/to/tb_name.v"
	@echo "  RTL_SRCS=\"src/a.v src/b.v\""
	@echo "  EXTRA_SRCS=\"src/common.v\""
	@echo "  SIM=iverilog VVP=vvp"
	@echo "  GTKWAVE=gtkwave"
	@echo ""
	@echo "Examples:"
	@echo "  make"
	@echo "  make TOP=tb_apb_interface TB=sim/apb_interface/tb_apb_interface.v"
	@echo "  make wave"
	@echo "  make TOP=tb_other TB=sim/other/tb_other.v RTL_SRCS=\"src/other/*.v src/shared/*.v\""