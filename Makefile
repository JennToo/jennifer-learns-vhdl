.PHONY: all clean simulations

all: bitstreams simulations

define DEFINE_SIMULATION
simulations: build/work/$(1)/meta-sim-run
waves-$(1):
	gtkwave build/work/$(1)/waves.ghw
ghdl-lint: ghdl-lint-$(1)

ghdl-lint-$(1):
	ghdl -s --std=08 -Wall $(2)

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
bitstreams: build/work/$(1)/$(1).bit

program-$(1): build/work/$(1)/$(1).bit
	./scripts/ulx3s-ftp-upload $(ULX3S_ESP32_HOST) build/work/$(1)/$(1).bit

build/work/$(1)/pll.v: | build/work/$(1)
	ecppll $(3) --file $$@

build/work/$(1)/$(1).json: $(2) build/work/$(1)/pll.v | build/work/$(1)
	yosys -m ghdl -p "read_verilog build/work/$(1)/pll.v ; ghdl --no-formal --std=08 $(2) -e toplevel ; synth_ecp5 -json $$@ -top toplevel"

build/work/$(1)/$(1).config: build/work/$(1)/$(1).json
	nextpnr-ecp5 --json $$< --textcfg $$@ --lpf synth/ulx3s/ulx3s_v20.lpf --85k --package CABGA381

build/work/$(1)/$(1).bit: build/work/$(1)/$(1).config
	ecppack $$< $$@

build/work/$(1):
	mkdir -p $$@
endef

$(eval $(call DEFINE_SIMULATION,tb_spi_rx,src/spi_rx.vhd test/tb_spi_rx.vhd))
$(eval $(call DEFINE_SIMULATION,tb_sdram,src/util.vhd test/test_util.vhd test/sim_sdram.vhd src/basic_sdram.vhd test/tb_sdram.vhd))
$(eval $(call DEFINE_SIMULATION,tb_sdram_memtester,src/util.vhd src/memtester.vhd test/sim_sdram.vhd src/basic_sdram.vhd test/tb_sdram_memtester.vhd))
$(eval $(call DEFINE_SIMULATION,tb_util,src/util.vhd test/tb_util.vhd))
$(eval $(call DEFINE_SIMULATION,tb_lfsr,src/lfsr_16.vhd test/tb_lfsr.vhd))
$(eval $(call DEFINE_SIMULATION,tb_vga,src/util.vhd src/vga.vhd test/tb_vga.vhd))
$(eval $(call DEFINE_BITSTREAM,ulx3s_sdram_test,src/util.vhd src/basic_sdram.vhd src/memtester.vhd src/lfsr_16.vhd synth/ulx3s/sdram_test/toplevel.vhd,--clkin 25 --clkout0 100))

clean:
	rm -rf build
