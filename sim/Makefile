IVERILOG ?= iverilog
VVP      ?= vvp
VERILATOR ?= verilator
PYTHON   ?= python3
BUILD    ?= build

QUESTA        ?= vsim
VLOG          ?= vlog
UVM_TEST      ?= axi_ucie_smoke_test
UVM_SEED      ?= 1
UVM_TXN_COUNT ?= 100
UVM_PLUSARGS  ?=

.PHONY: all smoke reference-smoke lint py-test regress experiment feedback questa questa-guided questa-memory clean

all: lint py-test smoke reference-smoke regress experiment feedback

$(BUILD):
	mkdir -p $(BUILD)

lint: | $(BUILD)
	$(IVERILOG) -g2012 -Wall -t null -s smoke_tb -f files_smoke.f

smoke: | $(BUILD)
	$(IVERILOG) -g2012 -Wall -s smoke_tb -o $(BUILD)/smoke.vvp -f files_smoke.f
	$(VVP) $(BUILD)/smoke.vvp

reference-smoke: | $(BUILD)
	$(VERILATOR) --binary --timing -Wall -Wno-fatal \
		--top-module reference_smoke_tb \
		-Mdir $(BUILD)/vlt_reference -o reference_smoke \
		../tb/interfaces/axi_if.sv \
		../rtl/axi_ucie_reference_dut.sv \
		../tb/models/axi_memory_slave.sv \
		../tb/reference_smoke_tb.sv
	./$(BUILD)/vlt_reference/reference_smoke

py-test:
	cd .. && PYTHONPATH=python $(PYTHON) -m unittest discover -s tests -p "test_*.py"

regress:
	cd .. && mkdir -p build && PYTHONPATH=python $(PYTHON) -m cgverif.regress \
		--mode guided --iterations 24 --transactions 8 --seed 1 \
		--out build/guided_regression.json

experiment:
	cd .. && mkdir -p build && PYTHONPATH=python $(PYTHON) -m cgverif.experiment \
		--runs 8 --iterations 24 --transactions 8 --seed 1 \
		--out build/experiment.json

feedback:
	cd .. && mkdir -p build && $(PYTHON) scripts/coverage_feedback.py \
		--input examples/coverage.sample.json \
		--output build/next_bias.json

# Optional commercial-UVM flow. The default open-source CI does not require Questa.
questa:
	rm -rf work transcript vsim.wlf
	vlib work
	$(VLOG) -sv -L uvm -f files.f
	$(QUESTA) -c -L uvm tb_top \
		+UVM_TESTNAME=$(UVM_TEST) \
		+ntb_random_seed=$(UVM_SEED) \
		+TXN_COUNT=$(UVM_TXN_COUNT) \
		$(UVM_PLUSARGS) \
		-do "run -all; quit -f"

questa-guided:
	$(MAKE) questa UVM_TEST=axi_ucie_cov_guided_test UVM_PLUSARGS="$(UVM_PLUSARGS)"

questa-memory:
	$(MAKE) questa UVM_TEST=axi_ucie_memory_semantics_test UVM_PLUSARGS="+NO_STALL $(UVM_PLUSARGS)"

clean:
	rm -rf $(BUILD) ../build work transcript vsim.wlf
