.PHONY: all clean simulations

all: bitstreams simulations

define DEFINE_SIMULATION
simulations: build/work/$(1)/meta-sim-run
waves-$(1):
	gtkwave build/work/$(1)/waves.ghw

build/work/$(1)/$(1): $(2) | build/work/$(1)
	ghdl -s --std=08 --workdir=build/work/$(1) $(2)
	ghdl -a --std=08 -Wall --workdir=build/work/$(1) $(2)
	ghdl -e --std=08 --workdir=build/work/$(1) -o $$@ $(1)

build/work/$(1)/meta-sim-run: build/work/$(1)/$(1)
	build/work/$(1)/$(1) --wave="build/work/$(1)/waves.ghw" --assert-level=error
	touch $$@

build/work/$(1):
	mkdir -p $$@
endef

define DEFINE_BITSTREAM
bitstreams: build/work/$(1)/$(1).config

build/work/$(1)/$(1).json: $(2) | build/work/$(1)
	yosys -m ghdl -p "ghdl --no-formal $(2) -e toplevel ; synth_ecp5 -json $$@ -top toplevel"

build/work/$(1)/$(1).config: build/work/$(1)/$(1).json
	nextpnr-ecp5 --json $$< --textcfg $$@ --lpf synth/ulx3s/ulx3s_v20.lpf --85k --package CABGA381

build/work/$(1):
	mkdir -p $$@
endef

$(eval $(call DEFINE_SIMULATION,tb_spi_rx,src/spi_rx.vhd test/tb_spi_rx.vhd))
$(eval $(call DEFINE_SIMULATION,tb_sdram,src/util.vhd test/test_util.vhd test/sim_sdram.vhd src/basic_sdram.vhd test/tb_sdram.vhd))
$(eval $(call DEFINE_SIMULATION,tb_util,src/util.vhd test/tb_util.vhd))
$(eval $(call DEFINE_BITSTREAM,ulx3s_sdram_test,src/util.vhd src/basic_sdram.vhd synth/ulx3s/sdram_test/toplevel.vhd))

clean:
	rm -rf build
