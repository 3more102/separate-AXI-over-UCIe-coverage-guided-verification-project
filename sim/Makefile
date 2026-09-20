IVERILOG ?= iverilog
VVP      ?= vvp
PYTHON   ?= python3
BUILD    ?= build

.PHONY: all smoke lint py-test guided clean

all: lint py-test smoke

$(BUILD):
	mkdir -p $(BUILD)

lint: | $(BUILD)
	$(IVERILOG) -g2012 -Wall -t null -s smoke_tb -f files_smoke.f

smoke: | $(BUILD)
	$(IVERILOG) -g2012 -Wall -s smoke_tb -o $(BUILD)/smoke.vvp -f files_smoke.f
	$(VVP) $(BUILD)/smoke.vvp

py-test:
	cd .. && $(PYTHON) -m unittest discover -s tests -v

guided:
	cd .. && $(PYTHON) -m cgverif.regress --mode guided --iterations 16 --seed 9 --out reports/guided-smoke.json

clean:
	rm -rf $(BUILD)
