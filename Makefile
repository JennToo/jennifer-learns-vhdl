.PHONY: all clean simulations

all: bitstreams simulations

define DEFINE_SIMULATION
simulations: build/work/$(1)/meta-sim-run
waves-$(1):
	gtkwave build/work/$(1)/waves.ghw
ghdl-lint: ghdl-lint-$(1)

ghdl-lint-$(1):
	ghdl -s --std=08 -Wall $(SOURCES)

build/work/$(1)/$(1): $(SOURCES) | build/work/$(1)
	./scripts/vhdl-ls-library $(1) $(SOURCES)
	ghdl -s --std=08 --workdir=build/work/$(1) $(SOURCES)
	ghdl -a --std=08 -Wall --workdir=build/work/$(1) $(SOURCES)
	ghdl -e --std=08 --workdir=build/work/$(1) -o $$@ $(1)

build/work/$(1)/meta-sim-run: build/work/$(1)/$(1)
	build/work/$(1)/$(1) --wave="build/work/$(1)/waves.ghw" --assert-level=error
	touch $$@

build/work/$(1):
	mkdir -p $$@
endef

define DEFINE_ECP5_BITSTREAM
bitstreams: build/work/$(1)/$(1).bit

program-$(1): build/work/$(1)/$(1).bit
	./scripts/ulx3s-ftp-upload $(ULX3S_ESP32_HOST) build/work/$(1)/$(1).bit

build/work/$(1)/pll.v: | build/work/$(1)
	ecppll $(CLOCKS) --file $$@

build/work/$(1)/$(1).json: $(SOURCES) build/work/$(1)/pll.v | build/work/$(1)
	./scripts/vhdl-ls-library $(1) $(SOURCES)
	yosys -m ghdl -p "read_verilog build/work/$(1)/pll.v ; ghdl --no-formal --std=08 $(SOURCES) -e toplevel ; synth_ecp5 -json $$@ -top toplevel"

build/work/$(1)/$(1).config: build/work/$(1)/$(1).json
	nextpnr-ecp5 --json $$< --textcfg $$@ --lpf synth/ulx3s/ulx3s_v20.lpf --85k --package CABGA381

build/work/$(1)/$(1).bit: build/work/$(1)/$(1).config
	ecppack $$< $$@

build/work/$(1):
	mkdir -p $$@
endef

define DEFINE_QUARTUS_BITSTREAM
bitstreams: build/work/$(1)/meta-built

build/work/$(1)/meta-built: $(SOURCES) build/work/$(1)/meta-prepared
	./scripts/vhdl-ls-library $(1) $(SOURCES)
	cd build/work/$(1)/ && \
		set -x && \
		$(QUARTUS_ROOTDIR)/quartus_map --read_settings_files=on \
			--write_settings_files=off $(PROJECT) -c $(PROJECT) && \
		$(QUARTUS_ROOTDIR)/quartus_fit --read_settings_files=on \
			--write_settings_files=off $(PROJECT) -c $(PROJECT) && \
		$(QUARTUS_ROOTDIR)/quartus_asm --read_settings_files=on \
			--write_settings_files=off $(PROJECT) -c $(PROJECT) && \
		$(QUARTUS_ROOTDIR)/quartus_sta $(PROJECT) -c $(PROJECT)
	touch $$@

build/work/$(1)/meta-prepared: $(QSF_FILE) $(QPF_FILE) | build/work/$(1)
	cp $(QSF_FILE) $(QPF_FILE) build/work/$(1)/
	cd build/work/$(1)/ && \
		$(QUARTUS_ROOTDIR)/quartus_sh --prepare $(PROJECT)
	touch $$@

build/work/$(1):
	mkdir -p $$@

quartus-$(1): build/work/$(1)/meta-prepared
	cd build/work/$(1)/ && \
		$(QUARTUS_ROOTDIR)/quartus $(PROJECT)
endef

SOURCES := src/spi_rx.vhd test/tb_spi_rx.vhd
$(eval $(call DEFINE_SIMULATION,tb_spi_rx))

SOURCES := \
	src/pkg/axi.vhd src/pkg/math.vhd src/pkg/sdram.vhd \
	test/test_util.vhd test/sim_sdram.vhd \
	src/block_memory.vhd \
	src/basic_sdram.vhd test/tb_sdram.vhd
$(eval $(call DEFINE_SIMULATION,tb_sdram))

SOURCES := \
	src/pkg/axi.vhd src/pkg/math.vhd src/pkg/sdram.vhd \
	src/memtester.vhd test/sim_sdram.vhd \
	src/basic_sdram.vhd test/tb_sdram_memtester.vhd
$(eval $(call DEFINE_SIMULATION,tb_sdram_memtester))

SOURCES := src/pkg/math.vhd test/tb_util.vhd
$(eval $(call DEFINE_SIMULATION,tb_util))

SOURCES := src/lfsr_16.vhd test/tb_lfsr.vhd
$(eval $(call DEFINE_SIMULATION,tb_lfsr))

SOURCES := \
	src/pkg/graphics.vhd \
	src/pkg/math.vhd \
	src/vga_fifo_reader.vhd \
	src/vga.vhd \
	test/sim_fifo.vhd \
	test/tb_vga.vhd
$(eval $(call DEFINE_SIMULATION,tb_vga))

SOURCES := src/pkg/axi.vhd src/pkg/sdram.vhd src/pkg/math.vhd src/basic_sdram.vhd src/memtester.vhd src/lfsr_16.vhd synth/ulx3s/sdram_test/toplevel.vhd
CLOCKS  := --clkin 25 --clkout0 100
$(eval $(call DEFINE_ECP5_BITSTREAM,ulx3s_sdram_test))

PROJECT  := DE2_115_Computer
QSF_FILE := synth/DE2-115/Computer/$(PROJECT).qsf
QPF_FILE := synth/DE2-115/Computer/$(PROJECT).qpf
SOURCES  := \
	src/vga.vhd src/pkg/math.vhd src/pkg/graphics.vhd \
	synth/DE2-115/Computer/DE2_115_Computer.vhd \
	synth/DE2-115/Computer/clock_gen.ppf \
	synth/DE2-115/Computer/clock_gen.qip \
	synth/DE2-115/Computer/clock_gen.vhd \
	synth/DE2-115/Computer/$(PROJECT).sdc
$(eval $(call DEFINE_QUARTUS_BITSTREAM,de2-115_computer))

SOURCES := \
	src/pkg/math.vhd \
	src/uart_rx.vhd \
	test/tb_uart_rx.vhd
$(eval $(call DEFINE_SIMULATION,tb_uart_rx))

build/render: model/render.c
	clang-format -i $<
	gcc -O1 -g -std=c17 -I./3rd-party/stb -fsanitize=address,undefined -Wall \
		$< -o $@ -lSDL2

build/tb_gpu/tb_gpu.sim: test/tb_gpu.vhd test/tb_gpu.c scripts/build_tb_gpu
	./scripts/build_tb_gpu

.PHONY: tb_gpu
tb_gpu: build/tb_gpu/tb_gpu.sim
	$<

all: build/tb_gpu/tb_gpu.sim

.PHONY: render
render: build/render
	ASAN_OPTIONS=detect_leaks=0 $<

all: build/render

clean:
	rm -rf build
