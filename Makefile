.PHONY: all clean simulations

all: simulations

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

$(eval $(call DEFINE_SIMULATION,tb_spi_rx,src/spi_rx.vhd test/tb_spi_rx.vhd))
$(eval $(call DEFINE_SIMULATION,tb_sdram,src/util.vhd test/sim_sdram.vhd src/basic_sdram.vhd test/tb_sdram.vhd))
$(eval $(call DEFINE_SIMULATION,tb_util,src/util.vhd test/tb_util.vhd))

clean:
	rm -rf build
