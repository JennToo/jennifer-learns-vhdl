.PHONY: all clean simulations

all: simulations

define DEFINE_SIMULATION
simulations: build/work/$(1)/meta-sim-run
waves-$(1):
	gtkwave build/work/$(1)/waves.ghw

build/work/$(1)/$(1): $(2) | build/work/$(1)
	ghdl -s --workdir=build/work/$(1) $(2)
	ghdl -a -Wall --workdir=build/work/$(1) $(2)
	ghdl -e --workdir=build/work/$(1) -o $$@ $(1)

build/work/$(1)/meta-sim-run: build/work/$(1)/$(1)
	build/work/$(1)/$(1) --wave=build/work/$(1)/waves.ghw --assert-level=note
	touch $$@

build/work/$(1):
	mkdir -p $$@
endef

$(eval $(call DEFINE_SIMULATION,tb_spi_rx,src/spi_rx.vhd test/tb_spi_rx.vhd))

clean:
	rm -rf build
