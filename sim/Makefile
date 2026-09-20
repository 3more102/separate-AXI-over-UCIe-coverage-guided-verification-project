TEST ?= axi_ucie_smoke_test
SEED ?= 1
TOP  ?= top
QUESTA_HOME ?=
UVM_HOME ?= $(QUESTA_HOME)/verilog_src/uvm-1.2/src

.PHONY: questa compile run smoke clean

questa: compile run

compile:
	vlib work
	vlog -sv -mfcu +incdir+$(UVM_HOME) $(UVM_HOME)/uvm_pkg.sv -f files.f

run:
	vsim -c $(TOP) -sv_seed $(SEED) +UVM_TESTNAME=$(TEST) -do "run -all; quit -f"

smoke:
	PYTHONPATH=.. python3 -m unittest discover -s ../tests -v

clean:
	rm -rf work transcript vsim.wlf *.ucdb ../build
