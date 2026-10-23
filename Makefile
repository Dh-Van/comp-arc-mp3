TOP     = top
SOURCES = top.sv life.sv seed_rom.sv controller.sv ws2812b.sv
SEEDS   = seeds/red.txt seeds/green.txt seeds/blue.txt
PCF     = iceBlinkPico.pcf
BUILD   = build

.PHONY: all prog sim wave clean

all: $(BUILD)/$(TOP).bin

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/$(TOP).json: $(SOURCES) $(SEEDS) | $(BUILD)
	yosys -p "synth_ice40 -top $(TOP) -json $@" $(SOURCES)

$(BUILD)/$(TOP).asc: $(BUILD)/$(TOP).json $(PCF)
	nextpnr-ice40 --up5k --package sg48 --json $< --pcf $(PCF) --asc $@

$(BUILD)/$(TOP).bin: $(BUILD)/$(TOP).asc
	icepack $< $@

prog: $(BUILD)/$(TOP).bin
	dfu-util --device 1d50:6146 --alt 0 -D $< -R

sim: $(BUILD)/life_tb.out
	vvp -n $<

$(BUILD)/life_tb.out: life_tb.sv life.sv | $(BUILD)
	iverilog -g2012 -o $@ $^

wave: sim
	gtkwave $(BUILD)/life_tb.vcd &

clean:
	rm -rf $(BUILD)
