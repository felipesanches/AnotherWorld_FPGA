PROJ = anotherworld

all: $(PROJ).bit

%.json: %.v
	yosys -p 'synth_ecp5 -top anotherworld_cpu -json $@' $<

$(PROJ)_out.config: $(PROJ).json $(PROJ).lpf
	nextpnr-ecp5 --json $(PROJ).json --textcfg $(PROJ)_out.config --um5g-85k --package CABGA381 --lpf $(PROJ).lpf

$(PROJ).bit: $(PROJ)_out.config
	ecppack --svf $(PROJ).svf $(PROJ)_out.config $(PROJ).bit

clean:
	rm -f $(PROJ).bit $(PROJ)_out.config $(PROJ).svf $(PROJ).json

.PHONY: all prog clean
